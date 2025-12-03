package Libki::Controller::API::Public::Reservations;
use Moose;
use namespace::autoclean;
#use POSIX;

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

    my $config = $c->instance_config;

    my $username  = $c->request->params->{'username'} || undef;
    my $password  = $c->request->params->{'password'} || undef;
    my $client_id = $c->request->params->{'id'};
    my $begin_time = $c->request->params->{'reservation_date'}.' '.$c->request->params->{'reservation_hour'}.':'.$c->request->params->{'reservation_minute'}.':00';
    my $client = $c->model('DB::Client')->find( $client_id );
    my $log = $c->log();
    $log->debug("Creating reservation for $username / $client_id");
    my ( $user, $session ) = (undef, 0);

    if( $c->user_exists()) {
        $user = $c->user();
        $session = 1;
    }
    else {
        $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );
    }

    my ( $success, $error_code, $details ) = ( 1, undef, undef );    # Defaults for non-sip using systems

    unless ( $user && $user->is_guest eq 'Yes' ) {
        if( $session ) {
            $success = 1;
        }
        elsif ( $config->{SIP}->{enable} ) {
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
    my %check;
    if( $success ) {
        %check = $c->check_reservation($client,$user,$begin_time);
        if( $check{'error'} ) {
            $c->stash( 'success' => 0, 'reason' => $check{'error'}, details => $check{'detail'} );
            $success = 0;
        }
    }

    if( $success ) {
        if( $c->user_exists()) {
            $success =1;
        }
        else {
            $success = $c->authenticate({username => $username,password => $password,instance => $instance});
        }
    }

    if ( $success )
    {
        my $client = $c->model('DB::Client')->find( $client_id );
        my $error = {};

        if ( $c->model('DB::Reservation')->search( { user_id => $user->id(), client_id => $client_id } )->next() ) {
            $c->stash(
                'success' => 0,
                'reason'  => 'CLIENT_USER_ALREADY_RESERVED'
            );
        }
        elsif ( $c->model('DB::Reservation')->search( { user_id => $user->id() } )->next() ) {
            $c->stash( 'success' => 0, 'reason' => 'USER_ALREADY_RESERVED' );
        }
        elsif ( !$client->can_user_use( { user => $user, error => $error, c => $c } ) ) {
            $log->debug('User Cannot Use Client: ' . Data::Dumper::Dumper( $error ) );
            $c->stash( %$error );
        }
        else {
            if ( $c->model('DB::Reservation')->create( { instance => $instance, user_id => $user->id(), client_id => $client_id, begin_time => $begin_time , end_time => $check{'end_time'} } ) ) {
                $c->stash( 'success' => 1 );
            }
            else {
                $c->stash( 'success' => 0, 'reason' => 'UNKNOWN' );
            }
        }
    }
    else {
        $c->stash( 'success' => 0, 'reason' => $error_code || $check{'error'} || 'INVALID_USER', details => $details );
    }
    $c->logout() if ( !$session );

    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head2 delete

=cut

sub delete : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $password  = $c->request->params->{'password'};
    my $client_id = $c->request->params->{'id'};
    my $username = $c->request->params->{'username'};
    my $instance = $c->instance;
    my ($user, $auth, $session ) = ( undef, 0, 0 );
    if( $c->user_exists() ) {
        $user = $c->user();
        $auth = 1;
        $session = 1;
    }
    else {
        $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );
        $auth = $c->authenticate({username => $user->username,password => $password,instance => $instance});
    }

    if ( $user && $auth )
    {

        my $reservation = $c->model('DB::Reservation')->search( { user_id => $user->id(), client_id => $client_id } )->first;

        if(!$reservation)
        {
            $c->stash( 'success' => 0, 'reason' => 'NOTFOUND' );
        }
        elsif($reservation->delete())
        {
            $c->stash( 'success' => 1, );
        }
        else {
            $c->stash( 'success' => 0, 'reason' => 'UNKNOWN' );
        }
    }

    $c->logout() if( !$session );

    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head2 gettimelist

=cut

sub gettimelist : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $client_id = $c->request->params->{'id'};
    my $date = $c->request->params->{'reservation_date'};
    my %result = $c->get_time_list($client_id,$date);
    if ($result{'error'}) {
        $c->stash( 'success' => 0, 'reason' => $result{'error'} );
    }
    else {
        $c->stash( 'success' => 1, 'hlist' => $result{'hlist'}, 'mlist' => $result{'mlist'});
    }
    delete $c->stash->{Settings};
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
