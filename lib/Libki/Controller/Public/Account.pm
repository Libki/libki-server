package Libki::Controller::Public::Account;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Public::Account - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->user_exists() ) {
        my $reservation = $c->model( 'DB::Reservation' )->find( { user_id => $c->user->id() } ) || 0;
        my ( $begin, $end, $duration ) = ( undef, undef, 0 );

        if ($reservation) {
            $begin = DateTime::Format::MySQL->parse_datetime( $reservation->begin_time );
            $begin->set_time_zone( $c->tz );
            $begin =~ s/T/ /g;

            $end = DateTime::Format::MySQL->parse_datetime( $reservation->end_time );
            $end->set_time_zone( $c->tz );
            $end =~ s/T/ /g;

            $duration = abs( $end->subtract_datetime($begin)->in_units('minutes') );
        }

        $c->stash( 'reservation' => $reservation, 'template' => 'public/account.tt', 'begin' => $begin, 'end' => $end, 'duration' => $duration );
    }
    else {
        $c->response->redirect( $c->uri_for( '/public' ));
    }
}

=head2 cancel

    Cancel user's reservation

=cut

sub cancel :Local :Args(0) {
    my ( $self, $c ) = @_;
    if ($c->user_exists()){
        my $reservation = $c->model('DB::Reservation')->find({ user_id => $c->user->id()});
        if( $reservation) {
            $c->response->redirect( $c->uri_for('/public/account') ) if( $reservation->delete() );
        }
    }     
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

This file is part of Libki.

Libki is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as 
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

Libki is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Libki.  If not, see <http://www.gnu.org/licenses/>.

=cut

__PACKAGE__->meta->make_immutable;

1;
