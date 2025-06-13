package Libki::Controller::API::Client::v1_0;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Libki::SIP;
use Libki::LDAP;
use Libki::Hours;
use Libki::Utils::Printing;
use Libki::Utils::User;
use Libki::Clients;

use DateTime::Format::MySQL;
use DateTime;
use Encode qw(decode);
use JSON qw(to_json);
use List::Util qw(min);

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

    my $action  = $c->request->params->{'action'}  || q{};
    my $version = $c->request->params->{'version'} || q{};

    if ( $action eq 'register_node' ) {

        my $node_name = $c->request->params->{'node_name'};
        my $location  = $c->request->params->{'location'};
        my $type      = $c->request->params->{'type'};
        my $version   = $c->request->params->{'version'};
        my $ipaddress = $c->request->params->{'ipaddress'};
        my $macaddress= $c->request->params->{'macaddress'};
        my $hostname  = $c->request->params->{'hostname'};

        $c->model('DB::Location')->update_or_create(
            {
                instance => $instance,
                code     => $location,
            }
        ) if $location;

        my $client = $c->model('DB::Client')->update_or_new(
            {
                instance        => $instance,
                name            => $node_name,
                location        => $location ? $location : undef,
                type            => $type     ? $type     : undef,
                ipaddress       => $ipaddress? $ipaddress: undef,
                macaddress      => $macaddress? $macaddress: undef,
                hostname        => $hostname ? $hostname : undef,
                last_registered => $now,
            }
        );
        unless ($client->in_storage) {
            $client->insert;
            $log->debug( "Client Registered: $node_name / Version: $version" );
        }

        $client->get_from_storage;
        my $client_status = $client->status // q{};

        if ($client_status eq "unlock") {
            $c->stash(
                unlock   => 1,
                minutes  => $client->session->minutes,
                username => $client->session->user->username,
            );
        } elsif ($client_status eq "shutdown" || $client_status eq "suspend" || $client_status eq "restart") {
            $c->stash(
                $client_status => 1,
            );
        } elsif ($client_status eq "wakeup") {
            my $host = $c->setting('WOLHost') || '255.255.255.255';
            my $port = $c->setting('WOLPort') || 9;
            my @mac_addresses = Libki::Clients::get_wol_mac_addresses($c);

            $c->stash(
                wakeup => 1,
                wol_host => $host,
                wol_port => $port,
                wol_mac_addresses => \@mac_addresses,
            );
        }

        $client->update( { status => 'online' } ) if ( $client->status ne 'suspended' );

        if ( $c->setting('ReservationShowUsername') ne 'RSD' ) {
            my $reserved_for = $c->get_reservation_status($client);
            $c->stash( reserved_for => $reserved_for ) if ($reserved_for);
        }

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
            registered                 => !!$client,
            status                     => $client->status,
            ClientBehavior             => $c->stash->{Settings}->{ClientBehavior},
            ReservationShowUsername    => $c->stash->{Settings}->{ReservationShowUsername},

            EnableGuestSelfRegistration => $c->stash->{Settings}->{EnableGuestSelfRegistration},

            EnableClientSessionLocking   => $c->stash->{Settings}->{EnableClientSessionLocking},
            EnableClientPasswordlessMode => $c->stash->{Settings}->{EnableClientPasswordlessMode},

            TermsOfService             => decode( 'UTF-8', $c->stash->{Settings}->{TermsOfService} ),
            TermsOfServiceDetails      => decode( 'UTF-8', $c->stash->{Settings}->{TermsOfServiceDetails} ),

            BannerTopURL               => $c->stash->{Settings}->{BannerTopURL},
            BannerTopWidth             => $c->stash->{Settings}->{BannerTopWidth},
            BannerTopHeight            => $c->stash->{Settings}->{BannerTopHeight},

            BannerBottomURL            => $c->stash->{Settings}->{BannerBottomURL},
            BannerBottomWidth          => $c->stash->{Settings}->{BannerBottomWidth},
            BannerBottomHeight         => $c->stash->{Settings}->{BannerBottomHeight},

            Logo                       => $c->stash->{Settings}->{LogoURL},
            LogoWidth                  => $c->stash->{Settings}->{LogoWidth},
            LogoHeight                 => $c->stash->{Settings}->{LogoHeight},

            inactivityWarning          => $c->stash->{Settings}->{ClientInactivityWarning},
            inactivityLogout           => $c->stash->{Settings}->{ClientInactivityLogout},

            ClientTimeNotificationFrequency => $c->stash->{Settings}->{ClientTimeNotificationFrequency} || 5,
            ClientTimeWarningThreshold      => $c->stash->{Settings}->{ClientTimeWarningThreshold} || 5,

            ClientStyleSheet           => $c->stash->{Settings}->{ClientStyleSheet},

            InternetConnectivityURLs   => $c->stash->{Settings}->{InternetConnectivityURLs},
        );
    }
    elsif ( $action eq 'acknowledge_reservation' ) {
        my $client_name  = $c->request->params->{'node'};
        my $client = $c->model('DB::Client')->find( { name => $client_name } ) || undef;

        if( $client ) {
            my $reservation = $c->model('DB::Reservation')->search(
                {
                    instance => $instance,
                    client_id => $client->id
                },
                { order_by => { -asc => 'begin_time' } }
            )->first;

            if ($reservation) {
                my $reservation_end_time_dt = DateTime::Format::MySQL->parse_datetime( $reservation->end_time );
                $reservation_end_time_dt->set_time_zone( $c->tz );

                if ( $reservation_end_time_dt < $c->now ) {
                    $reservation->delete();
                }
            }
        }
    }
    else {
        my $username        = $c->request->params->{'username'};
        my $password        = $c->request->params->{'password'};
        my $client_name     = $c->request->params->{'node'};
        my $client_location = $c->request->params->{'location'};
        my $client_type     = $c->request->params->{'type'};

        my $units;
        my $user
            = $username
            ? $c->model('DB::User')->single( { instance => $instance, username => $username } )
            : undef;

        if ( $action eq 'login' ) {
            my $create_guest = $c->request->params->{'createGuest'};
            if ($create_guest) {
                if ( $c->setting('EnableGuestSelfRegistration') ) {
                    ( $user, $password ) = Libki::Utils::User::create_guest($c);
                    $username = $user->username;

                    $c->stash(
                        username => $username,
                        password => $password,
                    );
                }
                else {
                    delete( $c->stash->{Settings} );
                    $c->stash( authenticated => 0, error => "GUEST_SELF_REG_NOT_ENABLED" );
                    $c->res->status(501);
                    $c->forward( $c->view('JSON') );
                    return;
                }
            }

            $log->debug( __PACKAGE__
                  . " - username: $username, client_name: $client_name" );

            ## If SIP is enabled, try SIP first, unless we have a guest or staff account
            my ( $success, $error, $sip_fields ) = ( 1, undef, undef );
            if ( $config->{SIP}->{enable} ) {
                if (
                    !$user
                    || (   $user
                        && $user->is_guest() eq 'No'
                        && $user->creation_source eq 'SIP'
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
                        && $user->creation_source eq 'LDAP'
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
                    ( $user && $c->setting('EnableClientPasswordlessMode') ) ||
                    $c->authenticate(
                        {
                            username => $username,
                            password => $password,
                            instance => $instance,
                        }
                    )
                  )
                {
                    my $is_guest = $user->is_guest eq 'Yes';

                    my $client = $c->model('DB::Client')->single(
                        {
                            instance => $instance,
                            name     => $client_name,
                        }
                    );

                    my $minutes_until_closing = Libki::Hours::minutes_until_closing({ c => $c, location => $client_location });

                    #TODO: Move this to a unified sub, see TODO below
                    my $minutes_allotment = $user->minutes($c, $client);

                    # Get advanced rule if there is one
                    my $advanced_rule = $c->get_rule(
                            {
                                rule            => $is_guest ? 'guest_daily' : 'daily',
                                client_location => $client->location,
                                client_type     => $client->type,
                                client_name     => $client_name,
                                client_type     => $client_type,
                                user_category   => $user->category,
                            }
                    );

                    # Use advanced rule if there is one
                    if ( defined($advanced_rule) ) {
                        $minutes_allotment = $advanced_rule if ( $minutes_allotment > $advanced_rule );
                    }

                    unless ( defined( $minutes_allotment ) ) {
                        # Use 'simple' rules if no advanced rule exists
                        $minutes_allotment //=
                              $is_guest
                            ? $c->setting('DefaultGuestTimeAllowance')
                            : $c->setting('DefaultTimeAllowance');
                    }

                    my $error = {};    # Must be initialized as a hashref
                    if ( defined $minutes_until_closing && $minutes_until_closing <= 0 )
                    {
                        $c->stash( error => 'CLOSED' );
                    }
                    elsif ( $user->session && $user->session->client_id ne $client->id ) {
                        # If a user is logging into the same client they are currently "logged in" to according to the sessions table
                        # don't block the login. We will "resume" the session instead.
                        $c->stash( error => 'ACCOUNT_IN_USE' );
                    }
                    elsif ( $user->status eq 'disabled' ) {
                        $c->stash( error => 'ACCOUNT_DISABLED' );
                    }
                    elsif ( $minutes_allotment < 1 ) {
                        $c->stash( error => 'NO_TIME' );
                    }
                    elsif (
                        !$client->can_user_use(
                            { user => $user, error => $error, c => $c }
                        )
                      )
                    {
                        $c->stash( error => $error->{reason} );
                    }
                    else {
                        if ($client) {
                            if (defined $minutes_allotment) {
                                $c->model('DB::Allotment')->update_or_create(
                                    {
                                        instance => $c->instance,
                                        user_id  => $user->id,
                                        location => ( $c->setting('TimeAllowanceByLocation') && defined($client->location) ) ? $client->location : '',
                                        minutes  => $minutes_allotment,
                                    }
                                );
                            }
                            my %result = $c->check_login($client,$user);
                            my $reservation = $result{'reservation'};

                            # Allows exceptions to "Reservation only" client behavior
                            my $no_reservation_required = $c->get_rule(
                                {
                                    rule            => 'no_reservation_required',
                                    client_location => $client->location,
                                    client_type     => $client->type,
                                    client_name     => $client_name,
                                    client_type     => $client_type,
                                    user_category   => $user->category,
                                }
                            );

                            my $no_reservation = $reservation ? 0 : 1;
                            my $reservation_only = $c->stash->{'Settings'}->{'ClientBehavior'} =~ 'FCFS' ? 0 : 1;

                            if ( $reservation_only && $no_reservation && !$no_reservation_required )
                            {
                                $c->stash( error => 'RESERVATION_REQUIRED' );
                            }
                            elsif ( (!$reservation || $reservation->user_id() == $user->id() )
                                    && !$result{'error'} )
                            {
                                $reservation->delete() if $reservation;
                                %result = $c->check_login($client,$user);

                                my $session_id = $c->sessionid;

                                # Solves issue with some browsers not parsing correctly
                                $c->stash( units => "$result{'minutes'}" );

                                # If a user is logging into the same client they are currently "logged in" to according to the sessions table
                                # resume that session instead of creating a new session.
                                my $session;
                                if ( $user->session && $user->session->client_id eq $client->id ) {
                                    $session = $user->session;
                                }
                                else {
                                    # Check to see if there is a crashed session still hanging around
                                    # If there is, "log out" the previous session
                                    if ( $session = $client->session ) {
                                        $c->model('DB::Statistic')->create(
                                            {
                                                instance        => $instance,
                                                username        => $session->user->username,
                                                client_name     => $client->name,
                                                client_location => $client->location,
                                                client_type     => $client->type,
                                                action          => 'LOGOUT',
                                                created_on      => $c->now,
                                                session_id      => $session->session_id,
                                                info            => to_json(
                                                    {
                                                        client_version => $version
                                                    }
                                                ),
                                            }
                                        );

                                        $client->session->delete();

                                    }

                                    $session = $c->model('DB::Session')->create(
                                        {
                                            instance   => $instance,
                                            user_id    => $user->id,
                                            client_id  => $client->id,
                                            status     => 'active',
                                            minutes    => $result{minutes},
                                            session_id => $session_id,
                                        }
                                    );
                                    $c->prometheus->inc('logins');
                                }

                                $c->stash( authenticated => $session && 1 );

                                $c->model('DB::Statistic')->create(
                                    {
                                        instance        => $instance,
                                        username        => $username,
                                        client_name     => $client_name,
                                        client_location => $client_location,
                                        client_type     => $client_type,
                                        action          => 'LOGIN',
                                        created_on      => $now,
                                        session_id      => $session_id,
                                        info            => to_json(
                                            {
                                                client_version           => $version,
                                                user_id                  => $user->id,
                                                client_id                => $client->id,
                                                session_starting_minutes => $result{minutes},
                                            }
                                        ),
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
            unless ( $user ) {
                $c->response->body('User not found');
                $c->response->status(404);
            }

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
            unless ( $user ) {
                $c->response->body('User not found');
                $c->response->status(404);
            }

            my $session    = $user->session;

            if ($session) {
                my $session_id = $session->session_id;
                my $location   = $session->client->location;
                my $type       = $session->client->type;

                my $success = $session->delete() ? 1 : 0;
                $c->stash( logged_out => $success );

                $c->model('DB::Statistic')->create(
                    {
                        instance        => $instance,
                        username        => $username,
                        client_name     => $client_name,
                        client_location => $client_location,
                        client_type     => $client_type,
                        action          => 'LOGOUT',
                        created_on      => $now,
                        session_id      => $session_id,
                        info            => to_json(
                            {
                                client_version => $version
                            }
                        ),
                    }
                );
            } else {
                $c->stash( logged_out => 0 );
            }
        }
    }

    delete( $c->stash->{'Settings'} );
    $c->forward( $c->view('JSON') );
}

=head2 statistics

Client API method to send statistics/actions to the server.

=cut

sub statistics : Path('statistics') : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    $c->log()
        ->debug( "Libki::Controller::API::Client::v1_0::statistics(), instance: $instance, params: "
            . to_json( $c->request->params ) );

    my $client_name = $c->request->params->{'client_name'};
    my $username    = $c->request->params->{'username'};
    my $action      = $c->request->params->{'action'};

    my $client = $c->model('DB::Client')
        ->single( { instance => $instance, name => $client_name } );
        warn "CLIENT: $client";

    my $user = $c->model('DB::User')
        ->single( { instance => $instance, username => $username } );
        warn "USER: $user";

    $c->model('DB::Statistic')->create(
        {
            instance        => $c->instance,
            username        => $username,
            client_name     => $client->name,
            client_location => $client->location,
            client_type     => $client->type,
            action          => $action,
            created_on      => $c->now,
            session_id      => $c->sessionid,
            info            => to_json(
                {
                    user_id    => $user->id,
                    username   => $user->username,
                    client_id  => $client->id,
                }
            ),
        }
    );

    delete( $c->stash->{'Settings'} );
    $c->forward( $c->view('JSON') );
}

=head2 print

Client API method to send a print job to the server.

=cut

sub print : Path('print') : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    $c->log()
        ->debug( "Libki::Controller::API::Client::v1_0::print(), instance: $instance, params: "
            . to_json( $c->request->params ) );

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

        $print_file->filename =~ m/[a-zA-z]*(\d+)_(\d+)\.[a-zA-Z]+/;
        my $copies = $1 || 1;

        Libki::Utils::Printing::create_print_job_and_file(
            $c,
            {
                client      => $client,
                client_name => $client_name,
                copies      => $copies,
                location    => $location,
                print_file  => $print_file,
                printer_id  => $printer_id,
                user        => $user,
                username    => $username,
            }
        );

        $c->stash( success => 1 );
    }
    elsif ($client_name) {
        $c->stash(
            success => 0,
            error   => 'CLIENT NOT FOUND',
            client  => "$instance/$client_name"
        );
    }
    else {
        $c->stash(
            success => 0,
            error   => 'NO DATA',
        );
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
