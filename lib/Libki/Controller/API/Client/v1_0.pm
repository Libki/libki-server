package Libki::Controller::API::Client::v1_0;
use Moose;
use namespace::autoclean;

use IO::Socket::INET;

BEGIN { extends 'Catalyst::Controller'; }

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

        my $registered = $c->model('DB::Client')->update_or_create(
            {
                name            => $c->request->params->{'node_name'},
                location        => $c->request->params->{'location'},
                last_registered => $now,
            }
        );
        $registered &&= 1;

        $c->stash( registered => $registered );
    }
    else {
        my $username    = $c->request->params->{'username'};
        my $password    = $c->request->params->{'password'};
        my $client_name = $c->request->params->{'node'};
        my $client_location = $c->request->params->{'location'};

        my $user =
          $c->model('DB::User')->search( { username => $username } )->next();

        if ( $action eq 'login' ) {

            ## If SIP is enabled, try SIP first, unless we have a guest or staff account
            if ( $c->config->{SIP}->{enable} ) {
                if (
                    !$user
                    || (   $user
                        && $user->is_guest() eq 'No'
                        && !$c->check_any_user_role( $user,
                            qw/admin superadmin/ ) )
                  )
                {
                    my ( $success, $error ) =
                      authenticate_via_sip( $c, $username, $password );

                    if ($success) {
                        if ($user) {   ## User authenticated and exists in Libki
                            $user->set_column( 'password', $password );
                            $user->update();
                        }
                        else { ## User authenticated and does not exits in Libki
                            my $minutes =
                              $c->model('DB::Setting')
                              ->find('DefaultTimeAllowance')->value;

                            $user = $c->model('DB::User')->create(
                                {
                                    username => $username,
                                    password => $password,
                                    minutes  => $minutes,
                                    status   => 'enabled',
                                }
                            );
                        }
                    }
                    elsif ( $error eq 'INVALID_USER' ) {
                        ## This user may have existing in SIP, but is now deleted
                        ## In this case, we don't want the now deleted user to be
                        ## able to log into Libki, so let's attempt to delete that
                        ## username before we try to authenticate.
                        $c->model('DB::User')
                          ->search( { username => $username } )->delete();
                    }
                }
            }

            ## Process client requests
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
                                username   => $username,
                                client_name => $client_name,
                                client_location => $client_location,
                                action     => 'LOGIN',
                                when       => $now
                            }
                        );
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
                    username   => $username,
                    client_name => $client_name,
                    action     => 'LOGOUT',
                    when       => $now
                }
            );
        }
    }

    $c->forward( $c->view('JSON') );
}

sub authenticate_via_sip {
    my ( $c, $username, $password ) = @_;

    my ( $sec, $min, $hour, $day, $month, $year ) = localtime(time);
    $year += 1900;

    my $host = $c->config->{SIP}->{host};
    my $port = $c->config->{SIP}->{port};

    my $login_user_id  = $c->config->{SIP}->{username};
    my $login_password = $c->config->{SIP}->{password};
    my $location_code  = $c->config->{SIP}->{location};

    my $institution_id    = $location_code;
    my $patron_identifier = $username;
    my $terminal_password = $login_password;
    my $patron_password   = $password;
    my $transaction_date  = "$year$month$day    $hour$min$sec";

    my $socket = IO::Socket::INET->new("$host:$port")
      or die "ERROR in Socket Creation : $!\n";

    my $login_command =
      "9300CN$login_user_id|CO$login_password|CP$location_code";

    print $socket $login_command . "\n";

    my $data = <$socket>;

    if ( $data =~ '^941' ) {
        my $patron_status_request = "23001"
          . $transaction_date . "AO"
          . $institution_id . "|AA"
          . $patron_identifier . "|AC"
          . $terminal_password . "|AD"
          . $patron_password;
        print $socket $patron_status_request . "\n";

        $data = <$socket>;

        if ( CORE::index( $data, 'BLY' ) != -1 ) {
            if ( CORE::index( $data, 'CQY' ) != -1 ) {
                return 1;
            }
            else {
                return ( 0, 'INVALID_PASSWORD' );
            }
        }
        else {
            return ( 0, 'INVALID_USER' );
        }
    }
    else {
        return ( 0, 'CONNECTION_FAILURE' );
    }

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
