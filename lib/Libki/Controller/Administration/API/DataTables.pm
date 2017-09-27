package Libki::Controller::Administration::API::DataTables;
use Moose;
use namespace::autoclean;

use Encode qw(decode encode);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::DataTables - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub users : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    # We need to map the table columns to field names for ordering
    my @columns = qw/me.username me.minutes_allotment me.minutes me.status me.notes me.is_troublemaker client.name session.status/;

    my $search_term = $c->request->param("sSearch");
    my $filter;
    if ($search_term) {
        $filter = {
            'me.instance' => $instance,
            -or => [
                'me.username' => { 'like', "%$search_term%" },
                'me.notes'    => { 'like', "%$search_term%" },
            ]
        };
    }

    # Sorting options
    my @sorting;
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-' . $c->request->param("sSortDir_$i") => $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
    }

    # May need editing with a filter if the table contains records for other items
    # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
    # in this case, we'd only want the count of notes affecting the specific item,
    # not *all* items
    my $total_records = $c->model('DB::User')->search({ instance => $instance })->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::User')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @users = $c->model('DB::User')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => ( $c->request->param('iDisplayLength') > 0 ) ? $c->request->param('iDisplayLength') : undef,
            offset   => $c->request->param('iDisplayStart'),
            prefetch => { session => 'client' },
        }
    );

    my @results;
    foreach my $u (@users) {

	my $enc = 'UTF-8';

        my $r;
        $r->{'DT_RowId'} = $u->id;
        $r->{'0'}        = decode($enc,$u->username);
	$r->{'1'}        = $u->minutes_allotment;
        $r->{'2'}        = $u->minutes;
        $r->{'3'}        = $u->status;
        $r->{'4'}        = decode($enc,$u->notes);
        $r->{'5'}        = $u->is_troublemaker;
        $r->{'6'}        = defined( $u->session ) ? decode($enc,decode($enc,$u->session->client->name)) : undef;
        $r->{'7'}        = defined( $u->session ) ? $u->session->status : undef;

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

sub clients : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    # We need to map the table columns to field names for ordering
    my @columns =
      qw/ me.name me.location session.status user.username user.minutes_allotment user.minutes user.status user.notes user.is_troublemaker/;

    # Set up filters
    my $filter = { instance => $instance };

    my $search_term = $c->request->param("sSearch");
    if ($search_term) {
        $filter->{-or} = [
            'me.name'       => { 'like', "%$search_term%" },
            'me.location'   => { 'like', "%$search_term%" },
            'user.username' => { 'like', "%$search_term%" },

            #'user.notes'    => { 'like', "%$search_term%" },
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
                '-' . $c->request->param("sSortDir_$i") => $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
    }

    # May need editing with a filter if the table contains records for other items
    # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
    # in this case, we'd only want the count of notes affecting the specific item,
    # not *all* items
    my $total_records = $c->model('DB::Client')->search({ instance => $instance })->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Client')
      ->count( $filter, { prefetch => [ { 'session' => 'user' }, { 'reservation' => 'user' }, ] } );

    # Do the search, including any required sorting and pagination.
    my @clients = $c->model('DB::Client')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('iDisplayLength'),
            offset   => $c->request->param('iDisplayStart'),
            prefetch => [ { 'session' => 'user' }, { 'reservation' => 'user' }, ],
        }
    );

    my @results;
    foreach my $c (@clients) {

	my $enc = 'UTF-8';	

        my $r;
        $r->{'DT_RowId'} = $c->id;
        $r->{'0'}        = decode($enc,decode($enc,$c->name));
        $r->{'1'}        = decode($enc,decode($enc,$c->location));
        $r->{'2'}        = defined( $c->session ) ? $c->session->status : undef;
        $r->{'3'}        = defined( $c->session ) ? decode($enc,$c->session->user->username) : undef;
        $r->{'4'}        = defined( $c->session ) ? $c->session->user->minutes_allotment : undef;
        $r->{'5'}        = defined( $c->session ) ? $c->session->user->minutes : undef;
        $r->{'6'}        = defined( $c->session ) ? $c->session->user->status : undef;
        $r->{'7'}        = defined( $c->session ) ? decode($enc,$c->session->user->notes) : undef;
        $r->{'8'}        = defined( $c->session ) ? $c->session->user->is_troublemaker : undef;
        $r->{'9'}        = defined( $c->reservation ) ? decode($enc,$c->reservation->user->username) : undef;
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

sub statistics : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    # We need to map the table columns to field names for ordering
    my @columns = ( 'me.username', 'me.client_name', 'me.action', 'me.when' );

    my $search_term = $c->request->param("sSearch");
    my $filter;
    if ($search_term) {
        $filter = {
            -or => [
                'me.username'    => { 'like', "%$search_term%" },
                'me.client_name' => { 'like', "%$search_term%" },
                'me.when'        => { 'like', "%$search_term%" },
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
                '-' . $c->request->param("sSortDir_$i") => $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
    }

    my $total_records = $c->model('DB::Statistic')->search({ instance => $instance })->count;

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

	my $enc = 'UTF-8';

        my $r;
        $r->{'DT_RowId'} = $s->id;
        $r->{'0'}        = decode($enc,$s->username);
        $r->{'1'}        = decode($enc,decode($enc,$s->client_name));
        $r->{'2'}        = $s->action;
        $r->{'3'}        = $s->when->strftime('%m/%d/%Y %I:%M %p');

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
