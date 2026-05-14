package Libki::Controller::API::V2::Clients;

use Moose;
use namespace::autoclean;
use DateTime;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

=head1 NAME

Libki::Controller::API::V2::Clients - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for clients in Libki

=head1 METHODS

=head2 clients

=cut

sub clients : Path('/api/v2/clients') : Args(0) : ActionClass('REST') {}

=head2 client

=cut

sub client  : Path('/api/v2/clients') : Args(1) : ActionClass('REST') {}

=head2 clients_GET

GET /api/v2/clients

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

=cut

sub clients_POST {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $params = $c->req->data;
    my $schema = $c->model('DB')->schema;
    my $client;

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

    $self->status_created(
        $c,
        client   => $c->req->uri . '/' . $client->id,
        entity   => _serialize_client($c, $client),
    );
}

=head2 client_GET

GET /api/v2/clients/:id

=cut

sub client_GET {
    my ( $self, $c, $id ) = @_;

    my $client = $c->model('DB::Client')->find($id)
        or return $self->status_not_found($c, message => 'Client not found');

    $self->status_ok($c, entity => _serialize_client($c, $client));
}

=head2 client_PUT

PUT /api/v2/clients/:id

=cut

sub client_PUT {
    my ( $self, $c, $id ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $client = $c->model('DB::Client')->find($id)
        or return $self->status_not_found($c, message => 'Client not found');

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

=head2 client_DELETE

DELETE /api/v2/clients/:id

=cut

sub client_DELETE {
    my ( $self, $c, $id ) = @_;

    ($c->user && $c->assert_user_roles( qw/superadmin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $client = $c->model('DB::Client')->find($id)
        or return $self->status_not_found($c, message => 'Client not found');

    $client->delete;

    $self->status_no_content($c);
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
