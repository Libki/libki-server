package Libki::Controller::API::V2::Clients;

use Moose;
use namespace::autoclean;
use DateTime;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

sub clients : Path('/api/v2/clients') : Args(0) : ActionClass('REST') {}
sub client  : Path('/api/v2/clients') : Args(1) : ActionClass('REST') {}

# GET /api/v2/clients
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

# POST /api/v2/clients
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

# GET /api/v2/clients/:id
sub client_GET {
    my ( $self, $c, $id ) = @_;

    my $client = $c->model('DB::Client')->find($id)
        or return $self->status_not_found($c, message => 'Client not found');

    $self->status_ok($c, entity => _serialize_client($c, $client));
}

# PUT /api/v2/clients/:id
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

# DELETE /api/v2/clients/:id
sub client_DELETE {
    my ( $self, $c, $id ) = @_;

    ($c->user && $c->assert_user_roles( qw/superadmin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $client = $c->model('DB::Client')->find($id)
        or return $self->status_not_found($c, message => 'Client not found');

    $client->delete;

    $self->status_no_content($c);
}

# ---- Helper serialization ----

sub _serialize_client {
    my ( $c, $client ) = @_;

    my @location_hierarchy = map {
        $_->id
    } $client->location->ancestors;

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
        location           => $client->location->code,
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


__PACKAGE__->meta->make_immutable;

1;
