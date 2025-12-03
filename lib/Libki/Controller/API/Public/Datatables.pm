package Libki::Controller::API::Public::Datatables;
use Moose;
use namespace::autoclean;

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
    my @columns = qw/ me.name me.location me.type session.status session.minutes /;

    # Set up filters
    my $filter = { instance => $instance, status => "online" };

    my $search_term = $c->request->param("search[value]");
    if ($search_term) {
        $filter->{-or} = [
            'me.name'     => { 'like', "%$search_term%" },
            'me.location' => { 'like', "%$search_term%" },
            'me.type'     => { 'like', "%$search_term%" },
        ];
    }

    if ( $c->request->param("location_filter") ) {
        $filter->{'location'} = $c->request->param("location_filter");
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
    my $total_records = $c->model('DB::Client')->search({ instance => $instance })->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Client')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @clients = $c->model('DB::Client')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => ( $c->request->param('length') > 0 )
            ? $c->request->param('length')
            : undef,
            offset   => $c->request->param('start'),
    #       prefetch => [ { 'session' => 'user' }, { 'reservation' => 'user' }, ],
        }
    );

    my $client = $c;
    my @results;
    foreach my $c (@clients) {
        my $reservation= $client->model('DB::Reservation')->search(
             { 'client_id' => $c->id},
             {  order_by => { -asc => 'begin_time' } }
             )->first || undef;
        my $time = defined( $reservation ) ? $reservation->begin_time()->stringify() : undef;
        $time =~ s/T/ / if(defined($time));

        my $r;
        $r->{'DT_RowId'} = $c->id;
        $r->{'0'} = $c->name;
        $r->{'1'} = $c->location;
        $r->{'2'} = $c->type;
        $r->{'3'} = defined( $c->session ) ? $c->session->status : undef;
        $r->{'4'} = defined( $c->session ) ? $c->session->minutes : undef;
        $r->{'5'} = defined( $reservation ) ? $reservation->user->username : undef;
        $r->{'6'} = defined( $reservation ) ? $reservation->user->lastname . ", " . $reservation->user->firstname : undef;
        $r->{'7'} = $time;

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
    delete $c->stash->{Settings};
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
