package Libki::Controller::API::Client::v1_0;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Libki::SIP qw( authenticate_via_sip );
use Libki::LDAP qw( authenticate_via_ldap );
use Libki::Hours qw( minutes_until_closing );

use DateTime::Format::MySQL;
use DateTime;
use List::Util qw(min);
use PDF::API2;
use Date::Parse;
use POSIX;

=head1 NAME

Libki::Controller::API::Client::v1_0 - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

This is the all-singing all-dancing client api.
It does a lot, it does too much in fact.
TODO: Replace this api with a new RESTful api with individual endpoints for each action

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;
    my $config = $c->instance_config;

    my $log = $c->log();

    my $now = $c->now();

    my $action = $c->request->params->{'action'};

    if ( $action eq 'register_node' ) {

        my $node_name = $c->request->params->{'node_name'};
        my $location  = $c->request->params->{'location'};

        $c->model('DB::Location')->update_or_create(
            {
                instance => $instance,
                code     => $location,
            }
        ) if $location;

        my $client = $c->model('DB::Client')->update_or_create(
            {
                instance        => $instance,
                name            => $node_name,
                location        => $location ? $location : undef,
                last_registered => $now,
            }
        );
        $log->debug( "Client Registered: " . $client->name() );

        my $reserved_for = get_reservation_status($client);
        $c->stash( reserved_for => $reserved_for) if($reserved_for);

        my $age_limit = $c->request->params->{'age_limit'};
        if ($age_limit) {
            my @limits = split( /,/, $age_limit );
            foreach my $l (@limits) {
                my $comparison = substr( $l, 0, 2 );
                my $age = substr( $l, 2 );
                $log->debug("Age Limit Found: $comparison : $age");
                $c->model('DB::ClientAgeLimit')->update_or_create(
                    {
                        instance   => $instance,
                        client     => $client->id(),
                        comparison => $comparison,
                        age        => $age,
                    }
                );
            }
        }

        $c->stash(
            registered              => !!$client,
            ClientBehavior          => $c->stash->{'Settings'}->{'ClientBehavior'},
            ReservationShowUsername => $c->stash->{'Settings'}->{'ReservationShowUsername'},
            TermsOfService          => $c->stash->{'Settings'}->{'TermsOfService'},

            BannerTopURL    => $c->stash->{'Settings'}->{'BannerTopURL'},
            BannerTopWidth  => $c->stash->{'Settings'}->{'BannerTopWidth'},
            BannerTopHeight => $c->stash->{'Settings'}->{'BannerTopHeight'},

            BannerBottomURL    => $c->stash->{'Settings'}->{'BannerBottomURL'},
            BannerBottomWidth  => $c->stash->{'Settings'}->{'BannerBottomWidth'},
            BannerBottomHeight => $c->stash->{'Settings'}->{'BannerBottomHeight'},

            inactivityWarning => $c->stash->{'Settings'}->{'ClientInactivityWarning'},
            inactivityLogout  => $c->stash->{'Settings'}->{'ClientInactivityLogout'},

        );
    }
    elsif ( $action eq 'acknowledge_reservation' ) {
        my $client_name  = $c->request->params->{'node'};

        my $client = $c->model('DB::Client')->find( { name => $client_name } ) || undef;
        my $reservation= $c->model('DB::Reservation')->search(
                                                               {'client_id' => $client->id},
                                                               { order_by => { -asc => 'begin_time' }}
                                                             )->first || undef;

        if ($reservation) {
            if ( str2time($reservation->end_time) < str2time($c->now) ) {
                $reservation->delete();
            }
        }
    }
    else {
        my $username        = $c->request->params->{'username'};
        my $password        = $c->request->params->{'password'};
        my $client_name     = $c->request->params->{'node'};
        my $client_location = $c->request->params->{'location'};

        my $units;
        my $user = $c->model('DB::User')
          ->single( { instance => $instance, username => $username } );

        if ( $action eq 'login' ) {
            $log->debug( __PACKAGE__
                  . " - username: $username, client_name: $client_name" );

            ## If SIP is enabled, try SIP first, unless we have a guest or staff account
            my ( $success, $error, $sip_fields ) = ( 1, undef, undef );
            if ( $config->{SIP}->{enable} ) {
                if (
                    !$user
                    || (   $user
                        && $user->is_guest() eq 'No'
                        && !$c->check_any_user_role( $user,
                            qw/admin superadmin/ ) )
                  )
                {
                    my $ret =
                      Libki::SIP::authenticate_via_sip( $c, $user, $username,
                        $password );
                    $success = $ret->{success};
                    $error   = $ret->{error};
                    $user    = $ret->{user};

                    $sip_fields = $ret->{sip_fields};
                    if ($sip_fields) {
                        $c->stash(
                            hold_items_count => $sip_fields->{hold_items_count}
                        );
                    }
                }
            }

            ## If LDAP is enabled, try LDAP, unless we have a guest or staff account
            if ( $config->{LDAP}->{enable} ) {
                $log->debug( __PACKAGE__ . " attempting LDAP authentication" );
                if (
                    !$user
                    || (   $user
                        && $user->is_guest() eq 'No'
                        && !$c->check_any_user_role( $user,
                            qw/admin superadmin/ ) )
                  )
                {
                    my $ret =
                      Libki::LDAP::authenticate_via_ldap( $c, $user, $username,
                        $password );
                    $success = $ret->{success};
                    $error   = $ret->{error};
                    $user    = $ret->{user};
                }
            }

            ## Process client requests
            if ($success) {
                if (
                    $c->authenticate(
                        {
                            username => $username,
                            password => $password,
                            instance => $instance,
                        }
                    )
                  )
                {
                    my $client = $c->model('DB::Client')->single(
                        {
                            instance => $instance,
                            name     => $client_name,
                        }
                    );

                    my $error = {};    # Must be initialized as a hashref
                    if (
                        !$client->can_user_use(
                            { user => $user, error => $error, c => $c }
                        )
                      )
                    {
                        $c->stash( error => $error->{reason} );
                    }
                    else {
                        if ($client) {
                            my %result = check($client,$user,$c);
                            my $reservation = $result{'reservation'};

                            if ( !$result{'error'} )
                            {
                                my $session_id = $c->sessionid;

                                $user->minutes_allotment($user->minutes_allotment - $result{'minutes'});
                                $user->update();

                                $c->stash( units => "$result{'minutes'}" );
                                my $session = $c->model('DB::Session')->create(
                                    {
                                        instance   => $instance,
                                        user_id    => $user->id,
                                        client_id  => $client->id,
                                        status     => 'active',
                                        minutes    => $result{'minutes'},
                                        session_id => $session_id,
                                    }
                                );
                                $c->stash( authenticated => $session && 1 );

                                $c->model('DB::Statistic')->create(
                                    {
                                        instance        => $instance,
                                        username        => $username,
                                        client_name     => $client_name,
                                        client_location => $client_location,
                                        action          => 'LOGIN',
                                        created_on      => $now,
                                        session_id      => $session_id,
                                    }
                                );
                            }
                            else {
                                $c->stash( error => $result{'error'} );
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

            my @messages = $user->messages()->get_column('content')->all();

            $units = $user->session ? $user->session->minutes : 0;

            $c->stash(
                messages => \@messages,
                units    => "$units",     # Solves issue with some browsers not parsing correctly
                status   => $status,
            );

            $user->messages()->delete();
        }
        elsif ( $action eq 'logout' ) {
            my $session = $user->session;
            my $session_id = $session->session_id;
            my $location = $session->client->location;

            if( $session->minutes > 0 ) {
                $user->minutes_allotment($user->minutes_allotment + $session->minutes);
                $user->update();
            }
            my $success = $user->session->delete();
            $success &&= 1;
            $c->stash( logged_out => $success );

            $c->model('DB::Statistic')->create(
                {
                    instance        => $instance,
                    username        => $username,
                    client_name     => $client_name,
                    client_location => $client_location,
                    action          => 'LOGOUT',
                    created_on      => $now,
                    session_id      => $session_id,
                }
            );
        }
    }

    delete( $c->stash->{'Settings'} );
    $c->forward( $c->view('JSON') );
}

=head2 print

Client API method to send a print job to the server.

=cut

sub print : Path('print') : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;
    my $config   = $c->config->{instances}->{$instance} || $c->config;
    my $log      = $c->log();

    my $now = $c->now();

    my $client_name = $c->request->params->{'client_name'};
    my $username    = $c->request->params->{'username'};
    my $printer_id  = $c->request->params->{'printer'};
    my $location    = $c->request->params->{'location'};

    my $client = $c->model('DB::Client')
      ->single( { instance => $instance, name => $client_name } );

    my $user = $c->model('DB::User')
      ->single( { instance => $instance, username => $username } );

    if ( $client && $user ) {
        my $print_file = $c->req->upload('print_file');
        my $pdf_string = $print_file->decoded_slurp;
        my $pdf        = PDF::API2->open_scalar($pdf_string);
        my $pages      = $pdf->pages();

        my $printers = $c->get_printer_configuration;
        my $printer  = $printers->{printers}->{$printer_id};

        $print_file = $c->model('DB::PrintFile')->create(
            {
                instance        => $instance,
                filename        => $print_file->filename,
                content_type    => $print_file->type,
                data            => $pdf_string,
                pages           => $pages,
                client_id       => $client->id,
                client_name     => $client_name,
                client_location => $client->location,
                user_id         => $user->id,
                username        => $username,
                created_on      => $now,
                updated_on      => $now,
            }
        );

        my $print_job = $c->model('DB::PrintJob')->create(
            {
                instance      => $instance,
                type          => $printer->{type},
                status        => 'Pending',
                data          => undef,
                printer       => $printer_id,
                user_id       => $user->id,
                print_file_id => $print_file->id,
                created_on    => $now,
                updated_on    => $now,
            }
        );

        $c->stash( success => 1 );
    }
    else {

        $c->stash(
            success => 0,
            error   => 'CLIENT NOT FOUND',
            client  => "$instance/$client_name"
        );
    }

    delete( $c->stash->{'Settings'} );
    $c->forward( $c->view('JSON') );
}

=head2 get_reservation_status

Get the status of the first reservation.

=cut

sub get_reservation_status : Private : Args(1) {
    my ($client) = @_;
    my $c = Libki->new();
    my $timeout =  $c->model('DB::Setting')->find( { name => 'ReservationTimeout'} )->value;
    my $reservation= $c->model('DB::Reservation')->search(
       { 'client_id' => $client->id},
       { order_by => { -asc => 'begin_time' } }
       )->first || undef;

    my $status = undef;

    if ($reservation) {
        my $seconds = str2time($reservation->end_time) - str2time($reservation->begin_time);
        my $time_left = ($timeout * 60) > $seconds ? $seconds : ($timeout * 60);
        my $reserve = str2time($reservation->begin_time) + $time_left -time();
        if($reserve >= 0 && $reserve <= $time_left) {
            $status = $reservation->user->username.'  left '.floor($reserve/60).'m'.($reserve%60).'s';
        }
        elsif($reserve > $time_left && $reserve < 3600) {
            my $willbereserved = $reserve - $time_left;
            $status = $reservation->user->username().' in '.floor($willbereserved/60).'m'.($willbereserved%60).'s' ;
        }
    }
    return $status;
}

=head2 check

Check the time and the user, return the available time if possible.

=cut

sub check : Private : Args(3) {
    my($client,$user,$c) = @_;
    my $minutes_until_closing = Libki::Hours::minutes_until_closing( $c,$client->location );
    my $timeout = $c->setting('ReservationTimeout');
    my %result     = ('error' => 0, 'detail' => 0,'minutes' => 0, 'reservation' => undef );
    my $time_to_reservation = 0;
    my $reservation = $c->model('DB::Reservation')->find({ user_id => $user->id(), client_id => $client->id});

    # 1. Check user session, status and the closing time.
    if ( $user->session ) {
        $result{"error"} = 'ACCOUNT_IN_USE';
    }
    elsif ( $user->status eq 'disabled' ) {
        $result{"error"} = 'ACCOUNT_DISABLED';
    }
    elsif($minutes_until_closing && $minutes_until_closing <= 0) {
        $result{"error"} = 'CLOSED';
    }

    # 2. Check the allotment
    if(!$result{'error'} && !$reservation) {
        # Get advanced rule if there is one
        my $minutes_allotment = $user->minutes_allotment;
        my $is_guest = $user->is_guest eq 'Yes';
        unless ( defined($minutes_allotment) ) {
            $minutes_allotment = $c->get_rule( {
                    rule            => $is_guest ? 'guest_daily' : 'daily',
                    user_category   => $user->category,
                    client_location => $client->location,
                    client_name     => $client->name,
                 } );

            # Use 'simple' rules if no advanced rule exists
            $minutes_allotment //=
                  $is_guest
                ? $c->setting('DefaultGuestTimeAllowance')
                : $c->setting('DefaultTimeAllowance');
        }

        if ( $minutes_allotment < 1 ) {
            $result{"error"} = 'NO_TIME';
        }
    }

    # 3. Check the ClientBehavior setting
    # Allows exceptions to "Reservation only" client behavior
    if(!$result{'error'}) {
        my $no_reservation_required = $c->get_rule( {
                rule            => 'no_reservation_required',
                user_category   => $user->category,
                client_location => $client->location,
                client_name     => $client->name,
            } );

        my $no_reservation = $reservation ? 0 : 1;
        my $reservation_only = $c->stash->{'Settings'}->{'ClientBehavior'} =~ 'FCFS' ? 0 : 1;
        if ( $reservation_only && $no_reservation && !$no_reservation_required ) {
            $result{"error"} = 'RESERVATION_REQUIRED' ;
        }
    }

    # 4. Check if the time is available and get the time_to_reservation
    if(!$result{'error'}) {
        ## If the user has a reservation, delete the reservation and return the minutes to minutes_allotment.
        if($reservation) {
            $result{'reservation'} = $reservation;
            $user->minutes_allotment($user->minutes_allotment + ceil((str2time($reservation->end_time) - (str2time($reservation->begin_time) > str2time($c->now) ? str2time($reservation->begin_time): str2time($c->now)) )/60));
            $user->update();
            $reservation->delete();
        }

        my $first_reservation = $c->model('DB::Reservation')->search(
                        { client_id => $client->id },
                        { order_by => { -asc => 'begin_time' } }
                        )->first || undef;

        my $minutes_timeout = $timeout < $user->minutes_allotment ? $timeout:$user->minutes_allotment;
        my $begin_time = $c->now;

        ## Calculate the time to the first reservation.
        if($first_reservation) {
            if(
              ( (str2time($first_reservation->begin_time) - 60 ) <= str2time($c->now) )
              && str2time($c->now) <= ( str2time($first_reservation->begin_time) + $minutes_timeout*60 )
             ) {
              $result{'error'} = 'RESERVED_FOR_OTHER';
            }
            $begin_time = $first_reservation->begin_time;
            $time_to_reservation = floor( (str2time($begin_time) - str2time($c->now))/60 );
        }
    }

    # 5. Get the available minutes
    if(!$result{'error'}) {
        my $allotment = $user->minutes_allotment;
        my $allowance = $c->setting('DefaultSessionTimeAllowance');
        my @array = ($allowance, $allotment);
        push(@array, $minutes_until_closing) if ($minutes_until_closing);
        push(@array, $time_to_reservation) if ($time_to_reservation > 0);
        my $min = min @array;

        if($min > 0) {
            $result{'minutes'} = $min;
        }
        else {
            $result{'error'} = 'NO_TIME';
        }
    }

    return %result;
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
