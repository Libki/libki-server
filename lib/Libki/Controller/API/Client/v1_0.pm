package Libki::Controller::API::Client::v1_0;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Libki::SIP qw( authenticate_via_sip );

=head1 NAME

Libki::Controller::API::Client::v1_0 - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    my $now = sprintf(
        "%04d-%02d-%02d %02d:%02d:%02d",
        $year + 1900,
        $mon + 1, $mday, $hour, $min, $sec
    );

    my $action = $c->request->params->{'action'};

    if ( $action eq 'register_node' ) {

        my $client = $c->model('DB::Client')->update_or_create(
            {
                name            => $c->request->params->{'node_name'},
                location        => $c->request->params->{'location'},
                last_registered => $now,
            }
        );

        my $reservation = $client->reservation || undef;
        if ($reservation) {
            $c->stash( reserved_for => $reservation->user->username() );
        }

        $c->stash(
            registered     => !!$client,
            ClientBehavior => $c->stash->{'Settings'}->{'ClientBehavior'},
            ReservationShowUsername =>
              $c->stash->{'Settings'}->{'ReservationShowUsername'},

            BannerTopURL    => $c->stash->{'Settings'}->{'BannerTopURL'},
            BannerTopWidth  => $c->stash->{'Settings'}->{'BannerTopWidth'},
            BannerTopHeight => $c->stash->{'Settings'}->{'BannerTopHeight'},

            BannerBottomURL   => $c->stash->{'Settings'}->{'BannerBottomURL'},
            BannerBottomWidth => $c->stash->{'Settings'}->{'BannerBottomWidth'},
            BannerBottomHeight =>
              $c->stash->{'Settings'}->{'BannerBottomHeight'},
        );
    }
    elsif ( $action eq 'acknowledge_reservation' ) {
        my $client_name  = $c->request->params->{'node'};
        my $reserved_for = $c->request->params->{'reserved_for'};

        my $reservation =
          $c->model('DB::Reservation')
          ->search( {},
            { 'username' => $reserved_for, 'name' => $client_name } )->next();

        unless ( $reservation->expiration() ) {
            $reservation->expiration(
                DateTime::Format::MySQL->format_datetime(
                    DateTime->now( time_zone => 'local' )->add_duration(
                        DateTime::Duration->new(
                            minutes =>
                              $c->stash->{'Settings'}->{'ReservationTimeout'}
                        )
                    )
                )
            );
            $reservation->update();
        }
    }
    else {
        my $username        = $c->request->params->{'username'};
        my $password        = $c->request->params->{'password'};
        my $client_name     = $c->request->params->{'node'};
        my $client_location = $c->request->params->{'location'};

        my $user = $c->model('DB::User')->single( { username => $username } );

        if ( $action eq 'login' ) {

            ## If SIP is enabled, try SIP first, unless we have a guest or staff account
            my ( $success, $error ) = ( 1, undef );
            if ( $c->config->{SIP}->{enable} ) {
                if (
                    !$user
                    || (   $user
                        && $user->is_guest() eq 'No'
                        && !$c->check_any_user_role( $user,
                            qw/admin superadmin/ ) )
                  )
                {
                    ( $success, $error ) =
                      Libki::SIP::authenticate_via_sip( $c, $user, $username,
                        $password );
                }
            }

            ## Process client requests
            if ($success) {
                if (
                    $c->authenticate(
                        {
                            username => $username,
                            password => $password
                        }
                    )
                  )
                {
                    $c->stash( units => $user->minutes );

                    if ( $user->session ) {
                        $c->stash( error => 'ACCOUNT_IN_USE' );
                    }
                    elsif ( $user->status eq 'disabled' ) {
                        $c->stash( error => 'ACCOUNT_DISABLED' );
                    }
                    elsif ( $user->minutes < 1 ) {
                        $c->stash( error => 'NO_TIME' );
                    }
                    else {
                        my $client =
                          $c->model('DB::Client')
                          ->search( { name => $client_name } )->next();

                        if ($client) {
                            my $reservation = $client->reservation;

                            if (
                                !$reservation
                                && !(
                                    $c->stash->{'Settings'}
                                    ->{'ClientBehavior'} =~ 'FCFS'
                                )
                              )
                            {
                                $c->stash( error => 'RESERVATION_REQUIRED' );
                            }
                            elsif ( !$reservation
                                || $reservation->user_id() == $user->id() )
                            {
                                $reservation->delete() if $reservation;

                                my $session = $c->model('DB::Session')->create(
                                    {
                                        user_id   => $user->id,
                                        client_id => $client->id,
                                        status    => 'active'
                                    }
                                );
                                $c->stash( authenticated => $session && 1 );
                                $c->model('DB::Statistic')->create(
                                    {
                                        username        => $username,
                                        client_name     => $client_name,
                                        client_location => $client_location,
                                        action          => 'LOGIN',
                                        when            => $now
                                    }
                                );
                            }
                            else {
                                $c->stash( error => 'RESERVED_FOR_OTHER' );
                            }
                        }
                        else {
                            $c->stash( error => 'INVALID_CLIENT' );
                        }
                    }
                }
                else {
                    $c->stash( error => 'BAD_LOGIN' );
                }
            }
            else {
                $c->stash( error => $error );
            }
        }
        elsif ( $action eq 'clear_message' ) {
            $user->message('');
            my $success = $user->update();
            $success &&= 1;
            $c->stash( message_cleared => $success );
        }
        elsif ( $action eq 'get_user_data' ) {

            my $status;
            if ( $user->session ) {
                $status = 'Logged in';
            }
            elsif ( $user->status eq 'disabled' ) {
                $status = 'Kicked';
            }
            else {
                $status = 'Logged out';
            }

            $c->stash(
                message => $user->message,
                units   => $user->minutes,
                status  => $status,
            );

        }
        elsif ( $action eq 'logout' ) {
            my $success = $user->session->delete();
            $success &&= 1;
            $c->stash( logged_out => $success );

            $c->model('DB::Statistic')->create(
                {
                    username    => $username,
                    client_name => $client_name,
                    action      => 'LOGOUT',
                    when        => $now
                }
            );
        }
    }
    delete( $c->stash->{'Settings'} );
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
