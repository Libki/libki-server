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
