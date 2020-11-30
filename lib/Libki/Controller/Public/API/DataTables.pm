package Libki::Controller::Public::API::DataTables;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::DataTables - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for returning data in a format preferred by DataTables

=head1 METHODS


=head2 prints

Endpoint that returns DataTables JSON about print jobs and print file.

=cut

sub prints : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    if( !$c->user_exists ) {
        $c->response->body( 'Unauthorized' );
        $c->response->status(401);
        return;
    }

    my $user = $c->user();

    # We need to map the table columns to field names for ordering
    my @columns =
      qw( me.type me.status me.printer me.copies print_file.filename print_file.pages print_file.client_name print_file.username me.created_on );

    # Set up filters
    my $filter;
    my $search_term = $c->request->param("sSearch");
    if ($search_term) {
        $filter->{-or} = [
            'me.type'                => { 'like', "%$search_term%" },
            'me.status'              => { 'like', "%$search_term%" },
            'me.printer'             => { 'like', "%$search_term%" },
            'me.copies'              => { 'like', "%$search_term%" },
            'print_file.filename'    => { 'like', "%$search_term%" },
            'print_file.pages'       => { 'like', "%$search_term%" },
            'print_file.client_name' => { 'like', "%$search_term%" },
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

    # Public API should only show the logged in user's print jobs
    $filter->{'me.user_id'} = $user->id;

    my $total_records =
      $c->model('DB::PrintJob')->search( { instance => $instance, user_id => $user->id } )->count;

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
        $r->{'3'}        = $p->copies;
        $r->{'4'}        = $p->print_file->filename;
        $r->{'5'}        = $p->print_file->pages;
        $r->{'6'}        = $p->print_file->client_name;
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

=head2 reservations

Endpoint that returns DataTables JSON of reservations.

=cut

sub reservations  : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $schema = $c->model('DB::Setting')->result_source->schema || die("Couldn't Connect to DB");
    my $dbh = $schema->storage->dbh;

    # We need to map the table columns to field names for ordering
    my @columns =
       qw/ client.name user.username me.begin_time me.end_time /;

    # Set up filters
    my $filter = { 'me.instance' => $instance };

    my $search_term = $c->request->param("sSearch");
    if ($search_term) {
        $filter->{-or} = [
            'client.name'    => { 'like', "%$search_term%" },
            'user.username'  => { 'like', "%$search_term%" },
        ];
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
            rows     => $c->request->param('iDisplayLength'),
            offset   => $c->request->param('iDisplayStart'),
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
