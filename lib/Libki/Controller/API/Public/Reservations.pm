package Libki::Controller::API::Public::Reservations;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::API::Public::Reservations - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 create

=cut

sub create : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $config = $c->config->{instances}->{$instance} || $c->config;

    unless ( $config->{SIP} ) {
        my $yaml = $c->setting('SIPConfiguration');
        $config->{SIP} = YAML::XS::Load($yaml) if $yaml;
    }

    my $username  = $c->request->params->{'username'};
    my $password  = $c->request->params->{'password'};
    my $client_id = $c->request->params->{'id'};

    my $log = $c->log();
    $log->debug("Creating reservation for $username / $client_id");

    my $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );

    my ( $success, $error_code, $details ) = ( 1, undef, undef );    # Defaults for non-sip using systems

    unless ( $user && $user->is_guest eq 'Yes' ) {
        if ( $config->{SIP}->{enable} ) {
            $log->debug("Calling Libki::SIP::authenticate_via_sip( $c, $user, $username, $password )");
            my $ret = Libki::SIP::authenticate_via_sip( $c, $user, $username, $password );
            $success    = $ret->{success};
            $error_code = $ret->{error};
            $details    = $ret->{details};
            $user       = $ret->{user};
        }
        elsif ( $config->{LDAP}->{enable} ) {
            $log->debug("Calling Libki::LDAP::authenticate_via_ldap( $c, $user, $username, $password )");
            my $ret = Libki::LDAP::authenticate_via_ldap( $c, $user, $username, $password );
            $success    = $ret->{success};
            $error_code = $ret->{error};
            $details    = $ret->{details};
            $user       = $ret->{user};
        }
    } else {
        $log->debug("User $username is a guest, not trying external authentication");
    }

    if (
        $success
        && $c->authenticate(
            {
                username => $username,
                password => $password
            }
        )
      )
    {
        my $client = $c->model('DB::Client')->find( $client_id );
        my $error = {};

        if ( $c->model('DB::Reservation')->search( { user_id => $user->id(), client_id => $client_id } )->next() ) {
            $c->stash(
                'success' => 0,
                'reason'  => 'CLIENT_USER_ALREADY_RESERVED'
            );
        }
        elsif ( $c->model('DB::Reservation')->search( { client_id => $client_id } )->next() ) {
            $c->stash( 'success' => 0, 'reason' => 'CLIENT_ALREADY_RESERVED' );
        }
        elsif ( $c->model('DB::Reservation')->search( { user_id => $user->id() } )->next() ) {
            $c->stash( 'success' => 0, 'reason' => 'USER_ALREADY_RESERVED' );
        }
        elsif ( !$client->can_user_use( { user => $user, error => $error, c => $c } ) ) {
            $log->debug('User Cannot Use Client: ' . Data::Dumper::Dumper( $error ) );
            $c->stash( %$error );
        }
        else {
            if ( $c->model('DB::Reservation')->create( { instance => $instance, user_id => $user->id(), client_id => $client_id } ) ) {
                $c->stash( 'success' => 1 );
            }
            else {
                $c->stash( 'success' => 0, 'reason' => 'UNKNOWN' );
            }
        }
    }
    else {
        $c->stash( 'success' => 0, 'reason' => $error_code || 'INVALID_USER', details => $details );
    }

    $c->logout();

    $c->forward( $c->view('JSON') );
}

=head2 delete

=cut

sub delete : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $password  = $c->request->params->{'password'};
    my $client_id = $c->request->params->{'id'};

    my $user = $c->model('DB::Client')->find($client_id)->reservation->user;

    if (
        $c->authenticate(
            {
                username => $user->username,
                password => $password
            }
        )
      )
    {

        if ( $c->model('DB::Reservation')->search( { user_id => $user->id(), client_id => $client_id } )->next()
            ->delete() )
        {
            $c->stash( 'success' => 1, );
        }
        else {
            $c->stash( 'success' => 0, 'reason' => 'UNKNOWN' );
        }
    }

    $c->logout();

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
