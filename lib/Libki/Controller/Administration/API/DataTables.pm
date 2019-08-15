package Libki::Controller::Administration::API::DataTables;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

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

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns = qw/me.username me.lastname me.firstname me.category me.minutes_allotment session.minutes me.status me.notes me.is_troublemaker client.name session.status/;

    my $search_term = $c->request->param("sSearch");
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

    # Sorting options
    my @sorting;
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-'
                  . $c->request->param("sSortDir_$i") =>
                  $columns[ $c->request->param("iSortCol_$i") ]
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
            rows     => ( $c->request->param('iDisplayLength') > 0 )
            ? $c->request->param('iDisplayLength')
            : undef,
            offset   => $c->request->param('iDisplayStart'),
            prefetch => { session => 'client' },
        }
    );

    my @results;
    foreach my $u (@users) {

        my $r;
        $r->{'DT_RowId'} = $u->id;
        $r->{'0'}        = $u->username;
        $r->{'1'}        = $u->lastname;
        $r->{'2'}        = $u->firstname;
        $r->{'3'}        = $u->category;
        $r->{'4'}        = $u->minutes_allotment;
        $r->{'5'}        = $u->session ? $u->session->minutes : undef;
        $r->{'6'}        = $u->status;
        $r->{'7'}        = $u->notes;
        $r->{'8'}        = $u->is_troublemaker;
        $r->{'9'}        =
          defined( $u->session )
          ? $u->session->client->name : undef;
        $r->{'10'}        = defined( $u->session ) ? $u->session->status : undef;

        push( @results, $r );
    }

    $c->stash(
        {
            'iTotalRecords'        => $total_records,
            'iTotalDisplayRecords' => $count,
            'sEcho'                => $c->request->param('sEcho') || undef,
            'aaData'               => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 clients

Endpoint that returns DataTables JSON about clients registered with the server.

=cut

sub clients : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns =
      qw/ me.name me.location session.status user.username user.lastname user.firstname user.category user.minutes_allotment session.minutes user.status user.notes user.is_troublemaker/;

    # Set up filters
    my $filter = { 'me.instance' => $instance };

    my $search_term = $c->request->param("sSearch");
    if ($search_term) {
        $filter->{-or} = [
            'me.name'       => { 'like', "%$search_term%" },
            'me.location'   => { 'like', "%$search_term%" },
            'user.username' => { 'like', "%$search_term%" },
        ];
    }

    if ( $c->request->param("location_filter") ) {
        $filter->{'location'} = $c->request->param("location_filter");
    }

    # Sorting options
    my @sorting;
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-'
                  . $c->request->param("sSortDir_$i") =>
                  $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
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
            prefetch => [ { 'session' => 'user' }, { 'reservation' => 'user' } ]
        }
    );

    # Do the search, including any required sorting and pagination.
    my @clients = $c->model('DB::Client')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('iDisplayLength'),
            offset   => $c->request->param('iDisplayStart'),
            prefetch => [ { 'session' => 'user' }, { 'reservation' => 'user' } ]
        }
    );

    my @results;
    foreach my $c (@clients) {

        my $r;
        $r->{'DT_RowId'} = $c->id;
        $r->{'0'} = $c->name;
        $r->{'1'} = $c->location;
        $r->{'2'} = defined( $c->session ) ? $c->session->status : undef;
        $r->{'3'} = defined( $c->session ) ? $c->session->user->username : undef;
        $r->{'4'} = defined( $c->session ) ? $c->session->user->lastname : undef;
        $r->{'5'} = defined( $c->session ) ? $c->session->user->firstname : undef;
        $r->{'6'} = defined( $c->session ) ? $c->session->user->category : undef;
        $r->{'7'} = defined( $c->session ) ? $c->session->user->minutes_allotment : undef;
        $r->{'8'} = defined( $c->session ) ? $c->session->minutes : undef;
        $r->{'9'} = defined( $c->session ) ? $c->session->user->status  : undef;
        $r->{'10'} = defined( $c->session ) ? $c->session->user->notes : undef;
        $r->{'11'} = defined( $c->session ) ? $c->session->user->is_troublemaker : undef;
        $r->{'12'} = defined( $c->reservation ) ? $c->reservation->user->username : undef;
        push( @results, $r );
    }

    $c->stash(
        {
            'iTotalRecords'        => $total_records,
            'iTotalDisplayRecords' => $count,
            'sEcho'                => $c->request->param('sEcho') || undef,
            'aaData'               => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 statistics

Endpoint that returns DataTables JSON about the statistics table.

=cut

sub statistics : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns = ( 'me.username', 'me.client_name', 'me.action', 'me.created_on' );

    my $search_term = $c->request->param("sSearch");
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

    # Sorting options
    my @sorting;
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-'
                  . $c->request->param("sSortDir_$i") =>
                  $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
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
            rows     => $c->request->param('iDisplayLength'),
            offset   => $c->request->param('iDisplayStart'),
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

        push( @results, $r );
    }

    $c->stash(
        {
            'iTotalRecords'        => $total_records,
            'iTotalDisplayRecords' => $count,
            'sEcho'                => $c->request->param('sEcho') || undef,
            'aaData'               => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 prints

Endpoint that returns DataTables JSON about print jobs and print file.

=cut

sub prints : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns =
      qw( me.type me.status me.printer print_file.filename print_file.pages print_file.client_name print_file.username me.created_on );

    # Set up filters
    my $filter;
    my $search_term = $c->request->param("sSearch");
    if ($search_term) {
        $filter->{-or} = [
            'me.type'                 => { 'like', "%$search_term%" },
            'me.status'               => { 'like', "%$search_term%" },
            'me.printer'              => { 'like', "%$search_term%" },
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
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-'
                  . $c->request->param("sSortDir_$i") =>
                  $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
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
            rows     => ( $c->request->param('iDisplayLength') > 0 )
            ? $c->request->param('iDisplayLength')
            : undef,
            offset => $c->request->param('iDisplayStart') || 0,
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
        $r->{'3'}        = $p->print_file->filename;
        $r->{'4'}        = $p->print_file->pages;
        $r->{'5'}        = $p->print_file->client_name;
        $r->{'6'}        = $p->print_file->username;
	$r->{'7'}        = $p->created_on->iso8601;
        push( @results, $r );
    }

    $c->stash(
        {
            'iTotalRecords'        => $total_records,
            'iTotalDisplayRecords' => $count,
            'sEcho'                => $c->request->param('sEcho') || undef,
            'aaData'               => \@results,
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
