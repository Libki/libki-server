package Libki::Controller::API::V2::Sessions;

use Moose;
use namespace::autoclean;
use DateTime;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

sub sessions : Path('/api/v2/sessions') : Args(0) : ActionClass('REST') {}
sub session  : Path('/api/v2/sessions') : Args(1) : ActionClass('REST') {}

# GET /api/v2/sessions
sub sessions_GET {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my @sessions = $c->model('DB::Session')->search(
        {},
        {
            prefetch => [
                'client',
                'user'
            ]
        }
    );
    my @data = map { _serialize_session($c, $_) } @sessions;

    $self->status_ok($c, entity => \@data);
}

# GET /api/v2/sessions/:id
sub session_GET {
    my ( $self, $c, $id ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $session = $c->model('DB::Session')->search(
        { 
            "session_id" => $id 
        }
    )->first() or return $self->status_not_found($c, message => 'Session not found');

    $self->status_ok($c, entity => _serialize_session($c, $session));
}

# ---- Helper serialization ----

sub _serialize_session {
    my ( $c, $session ) = @_;

    my @client_location_hierarchy = map {
        $_->id
    } $session->client->location->ancestors;

    return {
        id                 => $session->session_id,
        client             => $session->client->name,
        client_id          => $session->client_id,
        location           => $session->client->location->code,
        location_id        => $session->client->location_id,
        location_hierarchy => \@client_location_hierarchy,
        status             => $session->status,
        user               => $session->user->username,
        user_id            => $session->user_id,
        user_category      => $session->user->category,
        minutes_remaining  => $session->minutes,
    };
}


__PACKAGE__->meta->make_immutable;

1;
