package Libki::Controller::API::Client::v1_0;
use Moose;
use namespace::autoclean;

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

        my $user =
          $c->model('DB::User')->search( { username => $username } )->next();

        if ( $action eq 'login' ) {
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
                                clientname => $client_name,
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
                    clientname => $client_name,
                    action     => 'LOGOUT',
                    when       => $now
                }
            );
        }
    }

    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

libki,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
