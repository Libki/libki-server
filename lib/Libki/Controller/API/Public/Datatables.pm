package Libki::Controller::API::Public::Datatables;
use Moose;
use namespace::autoclean;

use Encode qw(decode);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::API::Public::Datatables - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 clients

Public Datatables API for Libki clients

=cut

sub clients : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    # We need to map the table columns to field names for ordering
    my @columns = qw/ me.name me.location session.status user.minutes /;

    # Set up filters
    my $filter = { instance => $instance};

    my $search_term = $c->request->param("sSearch");
    if ($search_term) {
        $filter->{-or} = [
            'me.name'     => { 'like', "%$search_term%" },
            'me.location' => { 'like', "%$search_term%" },
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

    my $total_records = $c->model('DB::Client')->search({ instance => $instance })->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Client')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @clients = $c->model('DB::Client')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => ( $c->request->param('iDisplayLength') > 0 )
            ? $c->request->param('iDisplayLength')
            : undef,
            offset   => $c->request->param('iDisplayStart'),
            prefetch => [ { 'session' => 'user' }, { 'reservation' => 'user' }, ],
        }
    );

    my @results;
    foreach my $c (@clients) {

	my $enc = 'utf-8';

        my $r;
        $r->{'DT_RowId'} = $c->id;
        $r->{'0'}        = decode($enc,decode($enc,$c->name));
        $r->{'1'}        = decode($enc,decode($enc,$c->location));
        $r->{'2'}        = defined( $c->session ) ? $c->session->status : undef;
        $r->{'3'} = defined( $c->session ) ? $c->session->user->minutes : undef;
        $r->{'4'} = defined( $c->reservation ) ? $c->reservation->user->username : undef;

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
