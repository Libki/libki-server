package Libki::Controller::API::Public::Reservations;
use Moose;
use namespace::autoclean;
use Date::Parse;
use Libki::Hours qw( minutes_until_closing );
use List::Util qw( min );
use POSIX;

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

    my $username  = $c->request->params->{'username'};
    my $password  = $c->request->params->{'password'};
    my $client_id = $c->request->params->{'id'};
    my $begin_time = $c->request->params->{'reservation_date'}.' '.$c->request->params->{'reservation_hour'}.':'.$c->request->params->{'reservation_minute'}.':00';
    my $client = $c->model('DB::Client')->find( $client_id );

    my $log = $c->log();
    $log->debug("Creating reservation for $username / $client_id");

    my $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );

    my ( $success, $error_code, $details ) = ( 1, undef, undef );    # Defaults for non-sip using systems

    my %check = check('begin_time' => $begin_time, 'client' => $client, 'user' => $user, 'libki' => $c);
    if( $check{'error'} ) {
        $c->stash( 'success' => 0, 'reason' => $check{'error'}, details => $check{'detail'} );
        $success = 0;
        $log->debug( "reservation error:".$check{'detail'} );
    }
    else{

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
                password => $password,
                instance => $instance,
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
        elsif ( $c->model('DB::Reservation')->search( { user_id => $user->id() } )->next() ) {
            $c->stash( 'success' => 0, 'reason' => 'USER_ALREADY_RESERVED' );
        }
        elsif ( !$client->can_user_use( { user => $user, error => $error, c => $c } ) ) {
            $log->debug('User Cannot Use Client: ' . Data::Dumper::Dumper( $error ) );
            $c->stash( %$error );
        }
        else {
            if ( $c->model('DB::Reservation')->create( { instance => $instance, user_id => $user->id(), client_id => $client_id, begin_time => $begin_time , end_time => $check{'end_time'} } ) ) {
                $user->minutes_allotment($check{'allotment'});
                $user->update();
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

    my $instance = $c->instance;
    my $username = $c->request->params->{'username'};
    my $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );
    if (
        $c->authenticate(
            {
                username => $user->username,
                password => $password,
                instance => $instance,
            }
        )
      )
    {
        my $reservation = $c->model('DB::Reservation')->find({ user_id => $user->id(), client_id => $client_id});
        if ( $reservation ) {
            $user->minutes_allotment($user->minutes_allotment + ceil((str2time($reservation->end_time) - (str2time($reservation->begin_time) > str2time($c->now) ? str2time($reservation->begin_time): str2time($c->now)) )/60));
        }

        if ( $reservation->delete() )
        {
            $user->update();
            $c->stash( 'success' => 1, );
        }
        else {
            $c->stash( 'success' => 0, 'reason' => 'UNKNOWN' );
        }
    }

    $c->logout();

    $c->forward( $c->view('JSON') );
}

=head2 check

Check if the time is available and return the available time if possible

=cut

sub check : Local
{
    my %param      = @_;
    my $begin_time = $param{'begin_time'};
    my $client     = $param{'client'};
    my $user       = $param{'user'};
    my $c          = $param{'libki'};
    my $parser = DateTime::Format::Strptime->new( pattern =>'%Y-%m-%d %H:%M' );
    my %result     = ('error' => 0, 'detail' => 0, 'minutes' => 0,'allotment' => 0, 'end_time' => $parser->parse_datetime($begin_time));
    my $datetime = $parser->parse_datetime($begin_time);
    my @array;
    my $minutes_to_closing = Libki::Hours::minutes_until_closing( $c,$client->location,$parser->parse_datetime($begin_time) );
    my ( $minutes_left, $total_minutes ) = ( 0, 0);

    #1. Check to see if the time has been past
    if(str2time($begin_time) < str2time($c->now)) {
        $result{'error'} = 'INVALID_TIME';
    }

    #2. Check allowance
    if(!$result{'error'}) {
        my $allowance  = $c->model('DB::Setting')->find({ name => 'DefaultSessionTimeAllowance'})->value;
        if($allowance <= 0) {
           $result{'error'} = 'INVALID_TIME';
           $result{'detail'} = 'SessionTimeAlowance is 0';
        }
        else {
           push(@array, $allowance);
        }
    }

    #3. Check the closing time
    if ( !$result{'error'} && defined($minutes_to_closing) ) {
       if ($minutes_to_closing > 0 ) {
          push(@array, $minutes_to_closing);
       }
       else {
          $result{'error'} = 'CLOSING_TIME';
       }
    }

    #4. Check the existing reservations
    if(!$result{'error'}) {
        my $reservations= $c->model('DB::Reservation')->search(
        { 'client_id' => $client->id},
        {
              order_by   => { -asc => 'begin_time' },
        }
        ) || undef;

        while(my $r = $reservations->next) {
             $minutes_left = str2time($r->begin_time) - str2time($begin_time);
             if( str2time($r->begin_time) <= str2time($begin_time) && str2time($begin_time) < str2time($r->end_time) ) {
                $result{'error'} = 'INVALID_TIME';
                $result{'detail'} = 'Reserved';
                 last;
                }
             elsif($minutes_left > 0) {
               push(@array, floor($minutes_left/60));
               last;
             }
        }
    }

    #5. Check the session
    if(!$result{'error'}) {
        my $session =  $c->model('DB::Session')->find( {client_id => $client->id} );
        if($session) {
           if(str2time($begin_time) < (str2time($c->now)+$session->minutes*60)) {
              $result{'error'} = 'INVALID_TIME';
              $result{'detail'} = 'Someone else is using this client';
           }
        }
    }

    #6. Check minutes and minutes_allotment
    if(!$result{'error'}) {
        $total_minutes = $user->minutes_allotment;
        if($total_minutes > 0) {
            push(@array, $total_minutes);
        }
        else {
            $result{'error'}  = 'NO_TIME';
        }
    }

    #7. Check the minimum minutes limit preference
    if(!$result{'error'}) {
        my $minimum    = $c->model('DB::Setting')->find({ name => 'MinimumReservationMinutes'})->value;
        if($total_minutes <  $minimum || $total_minutes <= 0) {
           $result{'error'}  = 'INVALID_TIME';
           $result{'detail'} = 'The reservation is too short';
        }
    }

    #8. Return the minites and allotment
    if(!$result{'error'}){
        $result{'minutes'}   = min @array;
        $result{'allotment'} = $total_minutes - $result{'minutes'};
        $result{'end_time'}  = $result{'end_time'}->add(minutes => $result{'minutes'});
    }

    return %result;
}

=head1 AUTHOR

libki,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
