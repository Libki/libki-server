package Libki::Controller::API::V2::Clients;

use Moose;
use namespace::autoclean;
use DateTime;
use JSON qw(to_json);

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

=head1 NAME

Libki::Controller::API::V2::Clients - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for clients in Libki

=head1 METHODS

=head2 base

basis for clients endpoints

=cut

sub base : Chained('/') PathPart('api/v2/clients') CaptureArgs(0) {}

=head2 clients

base for actions on all clients

=cut

sub clients : Chained('base') PathPart('') Args(0) ActionClass('REST') {}

=head2 clients_GET

GET /api/v2/clients

List all clients

=cut

sub clients_GET {
    my ( $self, $c ) = @_;

    my @clients = $c->model('DB::Client')->search(
        {},
        {
            prefetch => [
                'location',
            ]
        }
    );
    my @data = map { _serialize_client($c, $_) } @clients;

    $self->status_ok($c, entity => \@data);
}

=head2 clients_POST

POST /api/v2/clients

REQUIRES: admin

=cut

sub clients_POST {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $params = $c->req->data;
    my $schema = $c->model('DB')->schema;
    my $client;

    eval {
        $schema->txn_do(sub {
            $client = $c->model('DB::Client')->create({
                name        => $params->{name},
                location_id => $params->{location_id},
                type        => $params->{type},
                ipaddress   => $params->{ipaddress},
                macaddress  => $params->{macaddress},
                hostname    => $params->{hostname},
                instance    => $c->instance
            });

        });
    };

    if (my $error = $@) {
        chomp $error;

        if ($error =~ /for key '([^']+)'/i) {
            return $self->status_bad_request(
                $c,
                message => "Duplicate value for unique field"
            );
        }

        if ($error =~ /foreign key constraint fails/i) {
            return $self->status_bad_request(
                $c,
                message => "Invalid reference to related object"
            );
        }

        return $self->status_bad_request(
            $c,
            message => $error
        );
    }

    $self->status_created(
        $c,
        location => $c->req->uri . '/' . $client->id,
        entity   => _serialize_client($c, $client),
    );
}

=head2 shutdown_all

GET /api/v2/clients/shutdown

Shutdown all clients by changing their statuses.
The status change will send a message to each client to initiate shutdown.

REQUIRES: admin

=cut

sub shutdown_all : Chained('base') PathPart('shutdown') Args(0) GET {
    my ( $self, $c, $location ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $success = 1;

    my $search;
    $search->{instance} = $c->instance;
    $search->{location} = $location if $location;
    my $clients = $c->model('DB::Client')->search($search);

    my $status = $c->setting('ClientShutdownAction') || 'shutdown';

    my $count = 0;
    while ( my $client = $clients->next() ) {
        if ($client->status eq 'online') {
            if ( $client->update( { status => $status } ) ) {
                $count++;
            } else {
                $success = 0;
            }

            $c->model('DB::Statistic')->create(
                {
                    instance        => $c->instance,
                    username        => $c->user->username,
                    client_name     => $client->name,
                    client_location => $client->location->code,
                    client_type     => $client->type,
                    action          => 'SHUTDOWN_ALL',
                    created_on      => $c->now,
                    session_id      => $c->sessionid,
                }
            );
        }
    }

    $self->status_ok($c, entity => {
        'success' => $success, 
        'count'  => $count
    });
}

=head2 restart_all

GET /api/v2/clients/restart

Restarts all clients by changing their statuses.
The status change will send a message to each client to initiate reboot.

REQUIRES: admin

=cut

sub restart_all : Chained('base') PathPart('restart') Args(0) GET {
    my ( $self, $c, $location ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $success = 1;

    my $search;
    $search->{instance} = $c->instance;
    $search->{location} = $location if $location;
    my $clients = $c->model('DB::Client')->search($search);

    my $count = 0;
    while ( my $client = $clients->next() ) {
        if ($client->status eq 'online') {
            if ( $client->update( { status => 'restart' } ) ) {
                $count++;
            } else {
                $success = 0;
            }

            $c->model('DB::Statistic')->create(
                {
                    instance        => $c->instance,
                    username        => $c->user->username,
                    client_name     => $client->name,
                    client_location => $client->location->code,
                    client_type     => $client->type,
                    action          => 'RESTART_ALL',
                    created_on      => $c->now,
                    session_id      => $c->sessionid,
                }
            );
        }
    }

    $self->status_ok($c, entity => {
        'success' => $success, 
        'count'  => $count
    });
}

=head2 wakeup

GET /api/v2/clients/wakeup

Wake up all clients using wake on lan.

REQUIRES: admin

=cut

sub wakeup : Chained('base') PathPart('wakeup') Args(0) GET {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $success = 0;

    my $wol_mode = $c->setting('WOLMode') || "server";
    if ( $wol_mode eq "server" ) {
        $success = Libki::Clients::wakeonlan($c);
    } elsif ( $wol_mode eq "client" ) {
        my $clients = $c->model('DB::Client')->search({ instance => $c->instance });
        while ( my $client = $clients->next() ) {
            if ($client->status eq 'online') {
                $success = 1 if $client->update( { status => 'wakeup' } );

                $c->model('DB::Statistic')->create(
                    {
                        instance        => $c->instance,
                        username        => $c->user->username,
                        client_name     => $client->name,
                        client_location => $client->location->code,
                        client_type     => $client->type,
                        action          => 'WAKEUP_ALL',
                        created_on      => $c->now,
                        session_id      => $c->sessionid,
                    }
                );
            }
        }
    }

    $self->status_ok($c, entity => {
        'success' => $success
    });
}


=head2 client

base for individual clients

=cut

sub client : Chained('base') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    my $client = $c->model('DB::Client')->find($id);

    unless ($client) {
        $self->status_not_found(
            $c,
            message => 'Client not found'
        );
        $c->detach;
    }

    $c->stash->{client} = $client;
}

=head2 client_item

functional chain for individual client records

=cut

sub client_item : Chained('client') PathPart('') Args(0) ActionClass('REST') {}

=head2 client_item_GET

GET /api/v2/clients/:id

=cut

sub client_item_GET {
    my ( $self, $c ) = @_;
    my $client = $c->stash->{client};

    $self->status_ok($c, entity => _serialize_client($c, $client));
}

=head2 client_item_PUT

PUT /api/v2/clients/:id

REQUIRES: admin

=cut

sub client_item_PUT {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $client = $c->stash->{client};

    my $params = $c->req->data;
    my $schema = $c->model('DB')->schema;

    $schema->txn_do(sub {

        $client->update({
            name        => $params->{name},
            location_id => $params->{location_id},
            type        => $params->{type},
            ipaddress   => $params->{ipaddress},
            macaddress  => $params->{macaddress},
            hostname    => $params->{hostname},
        });

    });

    $self->status_ok($c, entity => _serialize_client($c, $client));
}

=head2 client_item_DELETE

DELETE /api/v2/clients/:id

REQUIRES: superadmin

=cut

sub client_item_DELETE {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/superadmin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $client   = $c->stash->{client};
    my $success  = 0;
    my $instance = $c->instance;

    $c->model('DB::Reservation')->search({ client_id => $client->id })->delete();
    $c->model('DB::Session')->search({ client_id => $client->id })->delete();
    $success = 1 if $client->delete();

    $c->model('DB::Statistic')->create(
        {
            instance        => $instance,
            username        => $c->user->username,
            client_name     => $client->name,
            client_location => $client->location->code,
            client_type     => $client->type,
            action          => 'DELETE',
            created_on      => $c->now,
            session_id      => $c->sessionid,
        }
    );

    $self->status_ok($c, entity => {
        'success' => $success
    });
}


=head2 unlock

GET /api/v2/clients/:id/unlock

Unlocks a client by creating a session for a guest account.

REQUIRES: admin

=cut

sub unlock : Chained('client') PathPart('unlock') Args(0) GET {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $success = 0;
    my $client = $c->stash->{'client'};

    if ( defined($client) && $client->status eq 'online' && ! defined( $client->session ) ) {
        # get guest user for this client
        my $prefix_setting = $c->setting('GuestPassPrefix');
        my $prefix = $prefix_setting || 'guest';

        my $username = $prefix . "_" . $client->name;
        my $user = $c->model('DB::User')->find( { username => $username } );

        unless ( $user ) {
            my $password = String::Random::random_string("nnnn");
            my $now = $c->now();

            $user = $c->model('DB::User')->create(
                {
                    instance          => $c->instance,
                    username          => $username,
                    password          => $password,
                    status            => 'enabled',
                    is_guest          => 'Yes',
                    created_on        => $now,
                    updated_on        => $now,
                }
            );
        }

        # reset allowance and calculate session time
        my $advanced_rule = $c->get_rule(
            {
                rule            => 'guest_daily',
                client_location => $client->location->code,
                client_type     => $client->type,
                client_name     => $client->name,
                client_type     => $client->type,
                user_category   => $user->category,
            }
        );

        my $minutes_allotment = $advanced_rule if ( defined $advanced_rule );
        $minutes_allotment = $c->setting('DefaultGuestTimeAllowance') unless ( defined( $minutes_allotment ) );

        $c->model('DB::Allotment')->update_or_create(
            {
                instance    => $c->instance,
                user_id     => $user->id,
                location_id => ( $c->setting('TimeAllowanceByLocation') && defined($client->location) ) ? $client->location_id : undef,
                minutes     => $minutes_allotment,
            }
        );

        my %result = $c->check_login($client,$user);

        # create session
        if ( ! $result{'error'} && $result{'minutes'} > 0 ) {
            my $session_id = $c->sessionid;
            my $session = $c->model('DB::Session')->create(
                {
                    instance   => $c->instance,
                    user_id    => $user->id,
                    client_id  => $client->id,
                    status     => 'active',
                    minutes    => $result{'minutes'},
                    session_id => $session_id,
                }
            );

            if ( $session ) {
                $c->prometheus->inc('logins');

                $client->update( { status => 'unlock' } );
                $success = 1;

                $c->model('DB::Statistic')->create(
                    {
                        instance        => $c->instance,
                        username        => $c->user->username,
                        client_name     => $client->name,
                        client_location => $client->location->code,
                        client_type     => $client->type,
                        action          => 'UNLOCK',
                        created_on      => $c->now,
                        session_id      => $session_id,
                    }
                );
            }
        }
    }

    $self->status_ok($c, entity => {
        'success' => $success
    });
}

=head2 toggle_status

GET /api/v2/clients/:id/toggle_status

Switch client status.

REQUIRES: admin

=cut

sub toggle_status : Chained('client') PathPart('toggle_status') Args(0) GET {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $instance = $c->instance;
    my $success = 0;
    my $client = $c->stash->{'client'};

    if($client) {
        my $status = ( $client->status eq 'suspended' ) ? 'offline' : 'suspended';
        $client->set_column( 'status', $status );

        if ( $client->update() ) {
            $success = 1;

            $c->model('DB::Statistic')->create(
                {
                    instance        => $instance,
                    username        => $c->user->username,
                    client_name     => $client->name,
                    client_location => $client->location->code,
                    client_type     => $client->type,
                    action          => 'TOGGLE_STATUS',
                    created_on      => $c->now,
                    session_id      => $c->sessionid,
                    info            => to_json( { status => $status } ),
                }
            );
        }
    }

    $self->status_ok($c, entity => {
        'success' => $success, 
        'status'  => $client->status 
    });
}


=head2 shutdown

GET /api/v2/client/:id/shutdown

Shutdown a specific client by changing it's status.
The status change will send a message to the client to initiate shutdown.

REQUIRES: admin

=cut

sub shutdown : Chained('client') PathPart('shutdown') Args(0) GET {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $success = 0;
    my $client = $c->stash->{'client'};
    my $status = $c->setting('ClientShutdownAction') || 'shutdown';

    if ($client->status eq 'online') {
        $success = 1 if $client->update( { status => $status } );

        my $session = $client->session;
        my $user = $session ? $session->user : undef;

        $c->model('DB::Statistic')->create(
            {
                instance        => $c->instance,
                username        => $c->user->username,
                client_name     => $client->name,
                client_location => $client->location->code,
                client_type     => $client->type,
                action          => 'SHUTDOWN',
                created_on      => $c->now,
                session_id      => $c->sessionid,
                info            => to_json(
                    {
                        user_id   => $user ? $user->id : undef,
                        username  => $user ? $user->username : undef,
                        client_id => $client->id,
                    }
                ),
            }
        );
    }

    $self->status_ok($c, entity => {
        'success' => $success, 
        'status'  => $client->status 
    });
}

=head2 restart

GET /api/v2/clients/:id/restart

Restarts a specific client by changing it's status.
The status change will send a message to the client to initiate reboot.

REQUIRES: admin

=cut

sub restart : Chained('client') PathPart('restart') Args(0) GET {
    my ( $self, $c ) = @_;

    my $success = 0;
    my $client = $c->stash->{'client'};

    if ($client->status eq 'online') {
        $success = 1 if $client->update( { status => 'restart' } );

        $c->model('DB::Statistic')->create(
            {
                instance        => $c->instance,
                username        => $c->user->username,
                client_name     => $client->name,
                client_location => $client->location->code,
                client_type     => $client->type,
                action          => 'RESTART',
                created_on      => $c->now,
                session_id      => $c->sessionid,
            }
        );
    }

    $self->status_ok($c, entity => {
        'success' => $success, 
        'status'  => $client->status 
    });
}


=head2 _serialize_client

Serialize client data

=cut

sub _serialize_client {
    my ( $c, $client ) = @_;

    my @location_hierarchy;
    if ($client->location) {
        @location_hierarchy = map {
            $_->id
        } $client->location->ancestors;
    }

    my $session = $client->session;

    my $serialized_session;
    if ($session) {
        $serialized_session = {
            'id'      => $session->session_id,
            'minutes' => $session->minutes,
        };
    }

    return {
        id                 => $client->id,
        name               => $client->name,
        location           => $client->location ? $client->location->code : undef,
        location_id        => $client->location_id,
        location_hierarchy => \@location_hierarchy,
        status             => $client->status,
        type               => $client->type,
        ipaddress          => $client->ipaddress,
        macaddress         => $client->macaddress,
        hostname           => $client->hostname,
        current_session    => $serialized_session,
    };
}

=head1 AUTHOR

Ian Walls <ian@bywatersolutions.com>

=cut

=head1 LICENSE

This file is part of Libki.

Libki is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as 
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

Libki is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Libki.  If not, see <http://www.gnu.org/licenses/>.

=cut

__PACKAGE__->meta->make_immutable;

1;
