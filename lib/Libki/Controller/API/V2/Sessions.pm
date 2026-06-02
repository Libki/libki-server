package Libki::Controller::API::V2::Sessions;

use Moose;
use namespace::autoclean;
use DateTime;
use JSON qw(to_json);


BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

=head1 NAME

Libki::Controller::API::V2::Sessions - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for client sessions in Libki

=head1 METHODS

=head2 base

basis for sessions endpoints

=cut

sub base : Chained('/') PathPart('api/v2/sessions') CaptureArgs(0) {}

=head2 sessions

base for actions on all sessions

=cut

sub sessions : Chained('base') PathPart('') Args(0) ActionClass('REST') {}

=head2 sessions_GET

GET /api/v2/sessions

Lists current sessions

REQUIRES: admin

=cut

sub sessions_GET {
    my ( $self, $c ) = @_;

    unless ($c->user && $c->check_user_roles( qw/admin/ ) ) {
        $self->status_forbidden($c, message => "access denied");
        $c->detach;
    }

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


=head2 session

base for actions on individual sessions

REQUIRES: admin

=cut

sub session  : Chained('base') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    unless ($c->user && $c->check_user_roles( qw/admin/ ) ) {
        $self->status_forbidden($c, message => "access denied");
        $c->detach;
    }

    my $session = $c->model('DB::Session')->search(
        { 
            "session_id" => $id 
        }
    )->first();

    if ($session) {
        $c->stash->{session} = $session;
    } else {
        $self->status_not_found($c, message => 'Session not found');
        $c->detach;
    }
}

=head2 session_item

functional chain for individual session records

=cut

sub session_item : Chained('session') PathPart('') Args(0) ActionClass('REST') {}

=head2 session_item_GET

GET /api/v2/sessions/:id

Return details about an individual session

=cut

sub session_item_GET {
    my ( $self, $c, $id ) = @_;

    my $session = $c->stash->{'session'};

    $self->status_ok($c, entity => _serialize_session($c, $session));
}

=head2 session_item_DELETE

DELETE /api/v2/sessions/:id

Deletes a session and sets guest time allotment to zero if configured

=cut

sub session_item_DELETE {
    my ( $self, $c ) = @_;

    my $success = 0;

    my $session = $c->stash->{'session'};
    my $client  = $session->client;
    my $user = $session->user;

    # If ExpireRemainingGuestPassTimeOnLogout enabled and user is guest, set minutes to 0
    if ($user->is_guest eq 'Yes' && $c->setting('ExpireRemainingGuestPassTimeOnLogout') eq 'enabled' ) {
        $c->model('DB::Allotment')->update_or_create(
            {
                instance    => $c->instance,
                user_id     => $user->id,
                location_id => undef,
                minutes     => 0,
            }
        );
    }
    if ( $session->delete() ) {
        $success = 1;

        $c->model('DB::Statistic')->create(
            {
                instance        => $c->instance,
                username        => $c->user->username,
                client_name     => $client->name,
                client_location => $client->location->code,
                client_type     => $client->type,
                action          => 'FORCE_LOGOUT',
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
    }

    $self->status_ok($c, entity => {
        'success' => $success
    });
}

=head2 session_item_PUT

PUT /api/v2/sessions/:id

Updates a user's session minutes.

The data value 'minutes' can be an integer to replace the existing minutes.
If the number is prepended with a '+' or '-' the number will be added
or subtracted from the existing session minutes respectively.

The data value 'add_time_to_allotment' can be a Boolean, which will determine
whether to also add the 'minutes' value to the users allotment (not just the session)

=cut

sub session_item_PUT {
    my ( $self, $c ) = @_;

    ($c->user && $c->assert_user_roles( qw/admin/ ) ) or return $self->status_forbidden($c, message => "access denied");

    my $success  = 0;
    my $instance = $c->instance;

    my $session  = $c->stash->{'session'};
    my $client   = $session->client;

    my $params   = $c->req->data;
    my $minutes               = $params->{'minutes'};
    my $add_time_to_allotment = $params->{'add_time_to_allotment'};

    my $session_minutes_update = $session->minutes;
    my $minutes_previous = $session->minutes;
    if ( $minutes =~ /^[+-]\d+$/ ) {
        $session_minutes_update = $session->minutes + $minutes;
    } elsif ($minutes =~ /^(\d)+$/ ) {
        $session_minutes_update = $minutes;
    } else {
        return $self->status_bad_request($c, message => "invalid minutes value")
    }

    # guard against negative time updates
    $session_minutes_update = 0 if ( $session_minutes_update < 0 );

    $success = 1 if $session->update( { minutes => $session_minutes_update } );

    if ($add_time_to_allotment) {
        my $u = $session->user;

        # logic should be moved to User method, exists in lib/Libki/Controller/Administration/API/DataTables.pm as well
        my $allotment = $u->allotments->find(
            {
                'instance' => $instance,
                'location_id' => ( $c->setting('TimeAllowanceByLocation') )
                ? (
                    ( defined( $u->session ) && defined( $client->location_id ) )
                    ? $client->location_id
                    : undef
                    )
                : '',
            }
        );
        if ($allotment) {
            my $allotment_minutes_update = $allotment->minutes;
            if ( $minutes =~ /^[+-]\d+$/ ) {
                $allotment_minutes_update = $allotment->minutes + $minutes;
            } elsif ($minutes =~ /^(\d)+$/ ) {
                $allotment_minutes_update = $minutes;
            }
            $allotment_minutes_update = 0 if ( $allotment_minutes_update < 0 );

            $success &&= $allotment->update( { minutes => $allotment_minutes_update } );
        }
    }

    $c->model('DB::Statistic')->create(
        {
            instance        => $c->instance,
            username        => $c->user->username,
            client_name     => $client->name,
            client_location => $client->location->code,
            client_type     => $client->type,
            action          => 'MODIFY_TIME',
            created_on      => $c->now,
            session_id      => $c->sessionid,
            info            => to_json(
                {
                    minutes_previous      => $minutes_previous,
                    minutes               => $minutes,
                    add_time_to_allotment => $add_time_to_allotment,
                    client_id             => $client->id,
                }
            ),
        }
    );

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
