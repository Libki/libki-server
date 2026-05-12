package Libki::Controller::API::V2::Sessions;

use Moose;
use namespace::autoclean;
use DateTime;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

=head1 NAME

Libki::Controller::API::V2::Sessions - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for client sessions in Libki

=head1 METHODS

=head2 sessions

=cut
sub sessions : Path('/api/v2/sessions') : Args(0) : ActionClass('REST') {}

=head2 session

=cut

sub session  : Path('/api/v2/sessions') : Args(1) : ActionClass('REST') {}

=head2 sessions_GET

GET /api/v2/sessions

=cut

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

=head2 session_GET

GET /api/v2/sessions/:id

=cut

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

=head2 _serialize_session

Serialize session data

=cut

sub _serialize_session {
    my ( $c, $session ) = @_;

    my @client_location_hierarchy;
    if ($session->client->location) {
        @client_location_hierarchy = map {
            $_->id
        } $session->client->location->ancestors;
    }

    return {
        id                 => $session->session_id,
        client             => $session->client->name,
        client_id          => $session->client_id,
        location           => $session->client->location ? $session->client->location->code : undef,
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
