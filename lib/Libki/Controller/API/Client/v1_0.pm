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
        my $type      = $c->request->params->{'type'};

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
                type            => $type     ? $type     : undef,
                last_registered => $now,
            }
        );
        my $client_s = $c->model('DB::Client')->find( { name => $node_name } );

        if ($client_s->status eq "unlock") {
            $c->stash(
                unlock   => 1,
                minutes  => $client_s->session->minutes,
                username => $client_s->session->user->username,
            );
        } elsif ($client_s->status eq "shutdown" || $client_s->status eq "suspend" || $client_s->status eq "restart") {
            $c->stash(
                $client_s->status => 1,
            );
        }

        my $minutes_to_shutdown = $c->setting('ClientShutdownDelay');
        if (length($minutes_to_shutdown)) {
            my $minutes_until_closing = Libki::Hours::minutes_until_closing({ c => $c, location => $client_s->location });
            if ( defined $minutes_until_closing && ($minutes_until_closing + $minutes_to_shutdown) < 0 ) {
                my $status  = $c->setting('ClientShutdownAction') || 'shutdown';
                $c->stash(
                    $status => 1,
                );
            }
        }

        $client_s->update( { status => 'online' } ) if ( $client_s->status ne 'suspended' );
        $log->debug( "Client Registered: " . $client->name() );

        my $reserved_for = $c->get_reservation_status( $client );
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
            registered                 => !!$client,
            ClientBehavior             => $c->stash->{Settings}->{ClientBehavior},
            ReservationShowUsername    => $c->stash->{Settings}->{ReservationShowUsername},
            EnableClientSessionLocking => $c->stash->{Settings}->{EnableClientSessionLocking},
            TermsOfService             => $c->stash->{Settings}->{TermsOfService},

            BannerTopURL               => $c->stash->{Settings}->{BannerTopURL},
            BannerTopWidth             => $c->stash->{Settings}->{BannerTopWidth},
            BannerTopHeight            => $c->stash->{Settings}->{BannerTopHeight},

            BannerBottomURL            => $c->stash->{Settings}->{BannerBottomURL},
            BannerBottomWidth          => $c->stash->{Settings}->{BannerBottomWidth},
            BannerBottomHeight         => $c->stash->{Settings}->{BannerBottomHeight},

            inactivityWarning          => $c->stash->{Settings}->{ClientInactivityWarning},
            inactivityLogout           => $c->stash->{Settings}->{ClientInactivityLogout},
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
                if ( str2time($reservation->end_time) < str2time($c->now) ) {
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
                    if ( $minutes_until_closing && $minutes_until_closing <= 0 )
                    {
                        $c->stash( error => 'CLOSED' );
                    }
                    elsif ( $user->session ) {
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
                                        client_type     => $client_type,
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
            my $session    = $user->session;
            my $session_id = $session->session_id;
            my $location   = $session->client->location;
            my $type       = $session->client->type;

            my $success = $user->session->delete();
            $success &&= 1;
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
    my $type        = $c->request->params->{'type'};

    my $client = $c->model('DB::Client')
      ->single( { instance => $instance, name => $client_name } );

    my $user = $c->model('DB::User')
      ->single( { instance => $instance, username => $username } );

    if ( $client && $user ) {
        my $print_file = $c->req->upload('print_file');
        my $pdf_string = $print_file->decoded_slurp;
        my $pdf        = PDF::API2->open_scalar($pdf_string);
        my $pages      = $pdf->pages();

        $print_file->filename =~ m/[a-zA-z]*(\d+)_(\d+)\.[a-zA-Z]+/;
        my $copies = $1 || 1;

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
                client_type     => $client->type,
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
                copies        => $copies,
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
