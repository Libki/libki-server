package Libki::Controller::Administration::API::Client;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::Client - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 modify_time

=cut

sub modify_time : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $success = 0;

    my $client_id = $c->request->params->{'id'};
    my $minutes   = $c->request->params->{'minutes'};

    my $client = $c->model('DB::Client')->find($client_id);

    if ( defined($client) && defined( $client->session ) ) {
        my $user = $client->session->user;

        if ( $minutes =~ /^[+-]/ ) {
            $minutes = $user->minutes + $minutes;
        }

        $minutes = 0 if ( $minutes < 0 );

        $user->set_column( 'minutes', $minutes );

        if ( $user->update() ) {
            $success = 1;
        }
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 logout

=cut

sub logout : Local : Args(1) {
    my ( $self, $c, $client_id ) = @_;
    my $success = 0;

    my $client = $c->model('DB::Client')->find($client_id);

    if ( defined($client) && defined( $client->session ) ) {
        if ( $client->session->delete() ) {
            $success = 1;
        }
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 logout

=cut

sub reservation : Local : Args(1) {
    my ( $self, $c, $client_id ) = @_;

    my $client = $c->model('DB::Client')->find($client_id);

    my $instance = $c->instance;

    my $action    = $c->request->params->{action}   || q{};
    my $username  = $c->request->params->{username} || q{};

    if ( $action eq 'reserve' ) {
        my $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );

        if ( $user ) {
            if ( $c->model('DB::Reservation')->search( { user_id => $user->id() } )->next() ) {
                $c->stash(
                    'success' => 0,
                    'reason'  => 'USER_ALREADY_RESERVED'
                );
            }
            elsif ( $c->model('DB::Reservation')->create( { instance => $instance, user_id => $user->id, client_id => $client_id } ) ) {
                $c->stash( 'success' => 1 );
            }
            else {
                $c->stash( 'success' => 0, 'reason' => 'UNKNOWN' );
            }
        } else {
            $c->stash( 'success' => 0, 'reason' => 'USER_NOT_FOUND' );
        }
    } if ( $action eq 'cancel' ) {
        my $reservation = $client->reservation;
        my $success = $reservation->delete() ? 1 : 0;
        $c->stash( success => $success );
    } else {
        my $reserved = 0;
        if ( defined($client) && defined( $client->reservation ) ) {
            $reserved = 1;
        }

        $c->stash( reserved => $reserved );
    }
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
