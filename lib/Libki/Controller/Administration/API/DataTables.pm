package Libki::Controller::Administration::API::DataTables;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Encode qw(decode);

=head1 NAME

Libki::Controller::Administration::API::DataTables - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for returning data in a format preferred by DataTables

=head1 METHODS

=head2 users

Endpoint that returns DataTables JSON with data about users.

=cut

sub users : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/admin/ );

    my $instance = $c->instance;

    my $schema = $c->schema;
    my $dbh    = $schema->storage->dbh;

    my $params = $c->req->params;

    # We need to map the table columns to field names for ordering
    my @columns = qw/me.username me.lastname me.firstname me.category allotments.minutes session.minutes me.status me.notes me.is_troublemaker client.name session.status me.creation_source/;

    my $search_term = $params->{"search[value]"};
    my $filter;
    if ($search_term) {
        $filter = {
            'me.instance' => $instance,
            -or           => [
                'me.username' => { 'like', "%$search_term%" },
                'me.notes'    => { 'like', "%$search_term%" },
                'me.lastname' => { 'like', "%$search_term%" },
                'me.firstname' => { 'like', "%$search_term%" },
                'me.category' => {'like', "%$search_term%" },
            ]
        };
    }
    else {
        $filter = { 'me.instance' => $instance };
    }

    my $dt_sorting_columns = {};
    foreach my $key ( keys %$params ) {
        if ( $key =~ /^order/ ) {
            my $data = $params->{$key};

            my ( undef, $key1, $key2, $key3 ) = split(/\[/, $key );

            $key1 =~ s/\]//g if $key1;
            $key2 =~ s/\]//g if $key2;
            $key3 =~ s/\]//g if $key3;

            if ( $key3 ) {
                $dt_sorting_columns->{$key1}->{$key2}->{$key3} = $data;
            } elsif ( $key2 ) {
                $dt_sorting_columns->{$key1}->{$key2} = $data;
            } else {
                $dt_sorting_columns->{$key1} = $data;
            }
        }
    }

    my @sorting;
    for ( my $i = 0; $i < scalar keys %$dt_sorting_columns; $i++ ) {
        my $sort = $dt_sorting_columns->{$i};
        my $dir = $sort->{dir};
        my $index = $sort->{column};
        push(
            @sorting,
            {
                "-$dir" => $columns[ $index ]
            }
        );
    }

  # May need editing with a filter if the table contains records for other items
  # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
  # in this case, we'd only want the count of notes affecting the specific item,
  # not *all* items
    my $total_records =
      $c->model('DB::User')->search( { instance => $instance } )->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::User')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @users = $c->model('DB::User')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => ( $params->{length} > 0 )
                ? $params->{length}
                : undef,
            offset   => $params->{start},
            prefetch => [ { session => 'client' }, 'allotments' ],
            group_by => 'me.id',
        }
    );

    my @results;
    foreach my $u (@users) {
        # logic should be moved to User method, exists in lib/Libki/Controller/Administration/API/Client.pm as well
        my $minutes_allotment = $u->allotments->find({
            'instance' => $instance,
            'location' => ($c->setting('TimeAllowanceByLocation'))
                ? ( ( defined($u->session) && defined($u->session->client->location) ) ? $u->session->client->location : '' )
                : '',
        });

        my $userValues = {
            DT_RowId           => $u->id,
            category           => $u->category,
            client_name        => defined( $u->session ) ? $u->session->client->name : undef,
            creation_source    => $u->creation_source,
            firstname          => $u->firstname,
            funds              => $u->funds,
            is_troublemaker    => $u->is_troublemaker,
            lastname           => $u->lastname,
            minutes            => $u->session ? $u->session->minutes : undef,
            minutes_allotment  => defined( $minutes_allotment ) ? $minutes_allotment->minutes : undef,
            notes              => $u->notes,
            session_status     => defined( $u->session ) ? $u->session->status : undef,
            status             => $u->status,
            troublemaker_until => defined( $u->troublemaker_until ) ? $u->troublemaker_until->strftime( '%Y-%m-%d 23:59' ) : undef,
            username           => $u->username,
        };

        push( @results, $userValues );
    }

    $c->stash(
        {
            'recordsTotal'         => $total_records,
            'recordsFiltered'      => $count,
            'draw'                 => $params->{draw},
            'data'                 => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 clients

Endpoint that returns DataTables JSON about clients registered with the server.

=cut

sub clients : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/admin/ );

    my $instance = $c->instance;

    my $schema = $c->schema;
    my $dbh    = $schema->storage->dbh;

    # Get settings
    my $userCategories = $c->setting('UserCategories');
    my $showFirstLastNames = $c->setting('ShowFirstLastNames');

    # We need to map the table columns to field names for ordering
    my @columns =
      qw/ me.name me.location me.type session.status user.username user.lastname user.firstname user.category session.minutes user.status user.notes user.is_troublemaker me.status/;

    if ($userCategories eq '') {
        splice @columns, 6, 1;
    }

    if ($showFirstLastNames eq '0') {
        splice @columns, 4, 2;
    }

    # Set up filters
    my $filter = { 'me.instance' => $instance };

    my $search_term = $c->request->param("search[value]");
    if ($search_term) {
        $filter->{-or} = [
            'me.name'       => { 'like', "%$search_term%" },
            'me.location'   => { 'like', "%$search_term%" },
            'me.status'     => { 'like', "%$search_term%" },
            'me.type'       => { 'like', "%$search_term%" },
            'user.username' => { 'like', "%$search_term%" },
        ];
    }

    if ( $c->request->param("location_filter") ) {
        $filter->{'location'} = $c->request->param("location_filter");
    }

    if ( $c->request->param("type_filter") ) {
        $filter->{'type'} = $c->request->param("type_filter");
    }

    # Sorting options
    my @sorting;
    my $params = $c->request->params;

    # Find all order indices
    foreach my $key (keys %$params) {
        if ($key =~ /^order\[(\d+)\]\[column\]$/) {
            my $idx = $1;
            my $col_idx = $params->{"order[$idx][column]"};
            my $dir     = $params->{"order[$idx][dir]"} || 'asc';

            # Default to column index if no name mapping is provided
            my $col_name = $columns[$col_idx] // $col_idx;

            push @sorting, { "-" . $dir => $col_name };
        }
    }
  # May need editing with a filter if the table contains records for other items
  # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
  # in this case, we'd only want the count of notes affecting the specific item,
  # not *all* items
    my $total_records =
      $c->model('DB::Client')->search( { instance => $instance } )->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Client')->count(
        $filter,
        {
            prefetch => [ { 'session' => 'user' } ]
        }
    );

    # Do the search, including any required sorting and pagination.
    my @clients = $c->model('DB::Client')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('length'),
            offset   => $c->request->param('start'),
            prefetch => [ { 'session' => 'user' } ]
        }
    );
    my $client = $c;
    my @results;
    my $enc = 'UTF-8';
    foreach my $c (@clients) {
        my $reservation= $client->model('DB::Reservation')->search(
             { 'client_id' => $c->id},
             {  order_by => { -asc => 'begin_time' } }
             )->first || undef;

        my $begin = defined( $reservation ) ? $reservation->begin_time()->stringify() : undef;
        $begin =~ s/T/ / if(defined($begin));

        my $minutes_allotment = undef;
        if ( defined($c->session) ) {
            $minutes_allotment = $c->session->user->allotments->find({
                'instance' => $instance,
                'location' => ( $client->setting('TimeAllowanceByLocation') && defined($c->location) ) ? $c->location : '',
            });
        }

        my $clientValues = {
            name => decode( 'UTF-8', $c->name ),
            location => decode( 'UTF-8', $c->location ),
            type => decode( 'UTF-8', $c->type ),
            session_status => defined( $c->session ) ? $c->session->status : undef,
            username => defined( $c->session ) ? $c->session->user->username : undef,
            lastname => defined( $c->session ) ? $c->session->user->lastname : undef,
            firstname => defined( $c->session ) ? $c->session->user->firstname : undef,
            category => defined( $c->session ) ? $c->session->user->category : undef,
            minutes_allotment => defined( $minutes_allotment ) ?$minutes_allotment->minutes : undef,
            minutes => defined( $c->session ) ? $c->session->minutes : undef,
            user_status => defined( $c->session ) ? $c->session->user->status  : undef,
            notes => defined( $c->session ) ? $c->session->user->notes : undef,
            is_troublemaker => defined( $c->session ) ? $c->session->user->is_troublemaker : undef,
            reservation => defined( $reservation ) ? $reservation->user->username : undef,
            reservation_start => defined( $reservation ) ? $begin : undef,
            client_status => $c->status,
        };

        my $r;
        my $clientValuesCounter = 0;
        $clientValues->{'DT_RowId'} = $c->id;

        push( @results, $clientValues );
    }

    $c->stash(
        {
            'recordsTotal'       => $total_records,
            'recordsFiltered'    => $count,
            'draw'               => $c->request->param('draw') || undef,
            'data'               => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 statistics

Endpoint that returns DataTables JSON about the statistics table.

=cut

sub statistics : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/admin/ );

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns = ( 'me.username', 'me.client_name', 'me.action', 'me.created_on', 'me.info' );

    my $search_term = $c->request->param("search[value]");
    my $filter;
    if ($search_term) {
        $filter = {
            -or => [
                'me.username'    => { 'like', "%$search_term%" },
                'me.client_name' => { 'like', "%$search_term%" },
                'me.created_on'  => { 'like', "%$search_term%" },
                'me.action'      => { 'like', "%$search_term%" },
            ]
        };
    }

    # date filtering
    my $from = $c->request->param('from');
    my $to   = $c->request->param('to');

    my %date_filter;
    if ($from) {
        # append time for inclusivity if desired
        $date_filter{'>='} = "$from 00:00:00";
    }
    if ($to) {
        $date_filter{'<='} = "$to 23:59:59";
    }

    if (%date_filter) {
        my $created_on_filter = { 'me.created_on' => \%date_filter };

        if ($filter) {
            # merge with existing search filter
            $filter = {
                -and => [
                    $filter,
                    $created_on_filter,
                ],
            };
        } else {
            $filter = $created_on_filter;
        }
    }

    # Sorting options
    my @sorting;
    my $params = $c->request->params;

    # Find all order indices
    foreach my $key (keys %$params) {
        if ($key =~ /^order\[(\d+)\]\[column\]$/) {
            my $idx = $1;
            my $col_idx = $params->{"order[$idx][column]"};
            my $dir     = $params->{"order[$idx][dir]"} || 'asc';

            # Default to column index if no name mapping is provided
            my $col_name = $columns[$col_idx] // $col_idx;

            push @sorting, { "-" . $dir => $col_name };
         }
    }
    my $total_records =
      $c->model('DB::Statistic')->search( { instance => $instance } )->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Statistic')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @stats = $c->model('DB::Statistic')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('length'),
            offset   => $c->request->param('start'),
        }
    );

    my @results;
    foreach my $s (@stats) {

        my $r;
        $r->{'DT_RowId'} = $s->id;
        $r->{'0'}        = $s->username;
        $r->{'1'}        = $s->client_name;
        $r->{'2'}        = $s->action;
        $r->{'3'}        = $s->created_on->strftime('%m/%d/%Y %I:%M %p');
        $r->{'4'}        = $s->info;

        push( @results, $r );
    }

    $c->stash(
        {
            'recordsTotal'        => $total_records,
            'recordsFiltered'     => $count,
            'draw'                => $c->request->param('draw') || undef,
            'data'                => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 prints

Endpoint that returns DataTables JSON about print jobs and print file.

=cut

sub prints : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/admin/ );

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns =
      qw( me.type me.status me.printer me.copies print_file.filename print_file.pages print_file.client_name print_file.username me.created_on );

    # Set up filters
    my $filter;
    my $search_term = $c->request->param("search[value]");
    if ($search_term) {
        $filter->{-or} = [
            'me.type'                => { 'like', "%$search_term%" },
            'me.status'              => { 'like', "%$search_term%" },
            'me.printer'             => { 'like', "%$search_term%" },
            'me.copies'              => { 'like', "%$search_term%" },
            'print_file.filename'    => { 'like', "%$search_term%" },
            'print_file.pages'       => { 'like', "%$search_term%" },
            'print_file.client_name' => { 'like', "%$search_term%" },
            'print_file.username'    => { 'like', "%$search_term%" },
        ];
    }
    else {
        $filter = { 'me.instance' => $instance };
    }

    if ( $c->request->param("location_filter") ) {
        $filter->{'print_file.client_location'} = $c->request->param("location_filter");
    }

    # Sorting options
    my @sorting;
    my $params = $c->request->params;

    # Find all order indices
    foreach my $key (keys %$params) {
        if ($key =~ /^order\[(\d+)\]\[column\]$/) {
            my $idx = $1;
            my $col_idx = $params->{"order[$idx][column]"};
            my $dir     = $params->{"order[$idx][dir]"} || 'asc';

            # Default to column index if no name mapping is provided
            my $col_name = $columns[$col_idx] // $col_idx;

            push @sorting, { "-" . $dir => $col_name };
         }
    }

  # May need editing with a filter if the table contains records for other items
  # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
  # in this case, we'd only want the count of notes affecting the specific item,
  # not *all* items
    my $total_records =
      $c->model('DB::PrintJob')->search( { instance => $instance } )->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::PrintJob')
      ->count( $filter, { prefetch => [ { 'print_file' => 'user' } ] } );

    # Do the search, including any required sorting and pagination.
    my @prints = $c->model('DB::PrintJob')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => ( $c->request->param('length') > 0 )
            ? $c->request->param('length')
            : undef,
            offset => $c->request->param('start') || 0,
            prefetch => [ { 'print_file' => 'user' }, ],
        }
    );

    my @results;
    foreach my $p (@prints) {

        my $r;
        $r->{'DT_RowId'} = $p->id;
        $r->{'0'}        = $p->type;
        $r->{'1'}        = $p->status;
        $r->{'2'}        = $p->printer;
        $r->{'3'}        = $p->copies;
        $r->{'4'}        = $p->print_file->filename;
        $r->{'5'}        = $p->print_file->pages;
        $r->{'6'}        = $p->print_file->client_name;
        $r->{'7'}        = $p->print_file->username;
        $r->{'8'}        = $c->format_dt( { dt => $p->created_on, include_time => 1 } );
        push( @results, $r );
    }

    $c->stash(
        {
            'recordsTotal'         => $total_records,
            'recordsFiltered'      => $count,
            'draw'                 => $c->request->param('draw') || undef,
            'data'                 => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 reservations

Endpoint that returns DataTables JSON of reservations.

=cut

sub reservations  : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/admin/ );

    my $instance = $c->instance;

    my $schema = $c->schema;
    my $dbh    = $schema->storage->dbh;

    # We need to map the table columns to field names for ordering
    my @columns =
       qw/ client.name user.username me.begin_time me.end_time /;

    # Set up filters
    my $filter = { 'me.instance' => $instance };

    my $search_term = $c->request->param("search[value]");
    if ($search_term) {
        $filter->{-or} = [
            'client.name'    => { 'like', "%$search_term%" },
            'user.username'  => { 'like', "%$search_term%" },
        ];
    }

    # Sorting options
    my @sorting;
    my $params = $c->request->params;

    # Find all order indices
    foreach my $key (keys %$params) {
        if ($key =~ /^order\[(\d+)\]\[column\]$/) {
            my $idx = $1;
            my $col_idx = $params->{"order[$idx][column]"};
            my $dir     = $params->{"order[$idx][dir]"} || 'asc';

            # Default to column index if no name mapping is provided
            my $col_name = $columns[$col_idx] // $col_idx;

            push @sorting, { "-" . $dir => $col_name };
         }
    }

   # May need editing with a filter if the table contains records for other items
    # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
    # in this case, we'd only want the count of notes affecting the specific item,
    # not *all* items
    my $total_records =
      $c->model('DB::Reservation')->search( { instance => $instance } )->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Reservation')->count(
        $filter,
        {
            prefetch => [ 'client', 'user' ]
        }
    );

    # Do the search, including any required sorting and pagination.
    my @reservations = $c->model('DB::Reservation')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('length'),
            offset   => $c->request->param('start'),
            prefetch => [ 'client', 'user' ],
        }
    );

    my @results;
    foreach my $r (@reservations) {
        my $begin = $r->begin_time->stringify();
        $begin =~ s/T/ /;
        my $end = $r->end_time->stringify();
        $end =~ s/T/ /;

        my @reservationValues = (
            $r->client->name,
            $r->user->username,
            $begin,
            $end,
        );

        my $row;
        my $reservationValuesCounter = 0;
        $row->{'DT_RowId'} = $r->user->username;

        foreach my $reservationValue (@reservationValues) {
            $row->{$reservationValuesCounter} = $reservationValue;
            $reservationValuesCounter++;
        }

        push( @results, $row );
    }

    $c->stash(
        {
            'recordsTotal'        => $total_records,
            'recordsFiltered'     => $count,
            'draw'                => $c->request->param('draw') || undef,
            'data'                => \@results,
        }
    );
    $c->forward( $c->view('JSON') );

}

=head2 logs

Endpoint that returns DataTables JSON about the logs table.

=cut

sub logs : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles(qw/superadmin/);

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns = ( 'me.created_on', 'me.pid', 'me.hostname', 'me.level', 'me.message' );

    my $search_term = $c->request->param("search[value]");
    my $filter;
    if ($search_term) {
        $filter = {
            instance => $instance,
            -or      => [
                'me.created_on' => { 'like', "%$search_term%" },
                'me.pid'        => { 'like', "%$search_term%" },
                'me.hostname'   => { 'like', "%$search_term%" },
                'me.level'      => { 'like', "%$search_term%" },
                'me.message'    => { 'like', "%$search_term%" },
            ]
        };
    }
    else {
        $filter = { instance => $instance };
    }

    # Sorting options
    my @sorting;
    my $params = $c->request->params;

    # Find all order indices
    foreach my $key (keys %$params) {
        if ($key =~ /^order\[(\d+)\]\[column\]$/) {
            my $idx = $1;
            my $col_idx = $params->{"order[$idx][column]"};
            my $dir     = $params->{"order[$idx][dir]"} || 'asc';

            # Default to column index if no name mapping is provided
            my $col_name = $columns[$col_idx] // $col_idx;

            push @sorting, { "-" . $dir => $col_name };
         }
    }

    my $total_records = $c->model('DB::Log')->search( { instance => $instance } )->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Log')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @logs = $c->model('DB::Log')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('length'),
            offset   => $c->request->param('start'),
        }
    );

    my @results;
    foreach my $s (@logs) {
        my $r;
        $r->{'DT_RowId'} = $s->id;
        $r->{'0'}        = $s->created_on->strftime('%m/%d/%Y %I:%M %p');
        $r->{'1'}        = $s->pid;
        $r->{'2'}        = $s->hostname;
        $r->{'3'}        = $s->level;
        $r->{'4'}        = $s->message;

        push( @results, $r );
    }

    $c->stash(
        {
            'recordsTotal '        => $total_records,
            'recordsFiltered'      => $count,
            'draw'                 => $c->request->param('draw') || undef,
            'data'                 => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.   

=cut

__PACKAGE__->meta->make_immutable;

1;
