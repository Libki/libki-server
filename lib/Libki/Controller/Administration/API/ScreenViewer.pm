# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
package Libki::Controller::Administration::API::ScreenViewer;

use Moose;
use namespace::autoclean;

use JSON qw(to_json);
use Libki::ScreenViewer qw(mint_token normalize_reason);

BEGIN { extends 'Catalyst::Controller'; }

sub token : Path('token') : Args(0) {
    my ( $self, $c ) = @_;

    $self->_no_store($c);
    return $self->_error( $c, 403, 'Staff administrator access is required' )
        unless $c->user_exists && $c->check_user_roles('admin')
            && $c->user->instance eq $c->instance;

    return $self->_error( $c, 405, 'POST is required' )
        unless uc( $c->request->method // q{} ) eq 'POST';

    my $config = $c->config->{'Libki::ScreenViewer'} || { enabled => 0 };
    return $self->_error( $c, 404, 'Screen viewing is not enabled' )
        unless $config->{enabled};

    return $self->_error( $c, 404, 'Screen viewing is not enabled for this instance' )
        unless $c->instance eq $config->{instance};

    # An explicit HTTPS origin avoids trusting forwarded Host headers.
    # A cross-origin form cannot set X-Requested-With; do not enable CORS here.
    return $self->_error( $c, 403, 'Same-origin viewer request is required' )
        unless ($c->request->headers->header('Origin') // q{}) eq $config->{origin}
            && ($c->request->headers->header('X-Requested-With') // q{}) eq 'XMLHttpRequest';

    my $client_name = $c->request->params->{client} // q{};
    return $self->_error( $c, 404, 'Screen viewing is not enabled for that client' )
        unless $config->{clients}->{$client_name};

    my $reason = eval {
        normalize_reason( $c->request->params->{reason} );
    };
    return $self->_error( $c, 400, 'Select a valid reason for viewing this screen' )
        unless $reason;

    my $client = $c->model('DB::Client')->find(
        {
            instance => $c->instance,
            name     => $client_name,
        }
    );
    return $self->_error( $c, 404, 'Client was not found' ) unless $client;

    my $staff_username = eval { $c->user->username } // 'unknown';
    my $session = $client->session;
    my $patron_notice_queued = 0;

    if ($session) {
        my $notice_created = eval {
            $c->model('DB::Message')->create(
                {
                    content => join(
                        q{ },
                        'Library staff requested permission to view this screen for:',
                        $reason->{label} . q{.},
                        'The connection is view-only; staff cannot use your keyboard or mouse.',
                        'Please accept or reject the connection prompt shown on this computer.',
                    ),
                    instance => $c->instance,
                    user_id  => $session->user->id,
                }
            );
            1;
        };
        return $self->_error( $c, 503, 'Unable to notify the active patron' )
            unless $notice_created;
        $patron_notice_queued = 1;
    }

    my $audit_created = eval {
        $c->model('DB::Statistic')->create(
            {
                action      => 'SCREEN_VIEW_REQUESTED',
                client_name => $client_name,
                created_on  => $c->now,
                info        => to_json(
                    {
                        endpoint_consent_required => 1,
                        mode                      => 'view-only',
                        patron_notice_queued      => $patron_notice_queued,
                        reason                    => $reason->{code},
                        reason_label              => $reason->{label},
                        remote_address => $c->request->address // 'unknown',
                    }
                ),
                instance   => $c->instance,
                session_id => $c->sessionid,
                username   => $staff_username,
            }
        );
        1;
    };
    return $self->_error( $c, 503, 'Unable to record the screen-view audit event' )
        unless $audit_created;

    my $token = mint_token( $config, $client_name );

    $c->stash(
        {
            client       => $client_name,
            expires_in   => $config->{token_ttl},
            endpoint_consent_required => 1,
            mode         => 'view-only',
            patron_notice_queued => $patron_notice_queued,
            reason       => $reason->{code},
            reason_label => $reason->{label},
            token        => $token,
            vnc_password => $config->{clients}->{$client_name}->{password},
        }
    );
    $c->forward( $c->view('JSON') );
}

sub _error {
    my ( $self, $c, $status, $message ) = @_;

    $c->response->status($status);
    $c->stash( { error => $message } );
    $c->forward( $c->view('JSON') );
    return;
}

sub _no_store {
    my ( $self, $c ) = @_;

    $c->response->headers->header( 'Cache-Control' => 'no-store, private' );
    $c->response->headers->header( 'Pragma'        => 'no-cache' );
    $c->response->headers->header( 'X-Content-Type-Options' => 'nosniff' );
    $c->response->headers->header( 'Referrer-Policy' => 'no-referrer' );
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Libki::Controller::Administration::API::ScreenViewer - Staff viewer token API

=head1 ACTIONS

=head2 token

Handle a same-origin administrator POST for the configured instance/client.
Queue a notice when a patron session exists, record the request, then return a
short-lived single-use token and the dedicated view-only VNC credential.
Endpoint approval and view-only enforcement must be configured separately.

=head1 LICENSE

AGPL-3.0-or-later. Copyright 2026 City of Clinton, Iowa.

=cut
