package Libki::Controller::Administration::Login;
use Moose;
use namespace::autoclean;

use JSON qw(to_json);
use Libki::Auth::Entra;
use Libki::Auth::Session;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

LibkiServer::Controller::Admin::Login - Catalyst administration login controller

=head1 METHODS

=head2 index

Automatically start Microsoft Entra sign-in when it is enabled. If Entra is
disabled, retain the upstream-compatible local login as a recovery path.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $self->_set_no_store($c);
    my $entra_config = $self->_entra_config($c);
    if ( $entra_config->{enabled} ) {
        $c->response->redirect( $c->uri_for('/administration/login/entra') );
        $c->response->status(303) if uc( $c->request->method // 'GET' ) eq 'POST';
        return;
    }

    return $self->_local_login( $c, $entra_config, 0 );
}

=head2 emergency

Render and process the explicit local break-glass route. This route is linked
only from the Entra error screen and is never the normal staff landing page.

=cut

sub emergency : Path('emergency') : Args(0) {
    my ( $self, $c ) = @_;

    $self->_set_no_store($c);
    my $entra_config = $self->_entra_config($c);
    return $self->_local_login( $c, $entra_config, 1 );
}

sub _local_login {
    my ( $self, $c, $entra_config, $breakglass_mode ) = @_;

    $c->stash(
        entra_sso_enabled => $entra_config->{enabled} ? 1 : 0,
        breakglass_mode   => $breakglass_mode ? 1 : 0,
    );

    my $username  = $c->request->params->{username};
    my $password  = $c->request->params->{password};
    my $submitted = $c->request->params->{submitted} || 0;

    if ( uc( $c->request->method // 'GET' ) eq 'POST' && $username && $password ) {
        my $authenticated = 0;
        if ( !Libki::Auth::Entra->is_shadow_username($username) ) {
            $authenticated = $c->authenticate(
                {
                    username => $username,
                    password => $password,
                    instance => $c->instance,
                }
            );
        }

        if ($authenticated) {
            if ( $entra_config->{enabled} ) {
                $c->oidc('ENTRA')->delete_stored_data();
                delete $c->session->{oidc_auth};
            }
            Libki::Auth::Session->rotate_id($c);
            delete @{$c->session}{qw/staff_display_name staff_email staff_entra_oid staff_role_level staff_entra_expires_at/};
            $c->session->{staff_auth_source} = 'Local account';

            $c->model('DB::Statistic')->create(
                {
                    action     => 'ADMIN_LOGIN',
                    created_on => $c->now,
                    instance   => $c->instance,
                    session_id => $c->sessionid,
                    username   => $username,
                    info       => to_json( { auth_source => 'local' } ),
                }
            );

            my $remote = $c->request->address // 'unknown';
            my $message = "Local administration login used by '$username' from $remote";
            $entra_config->{enabled} ? $c->log->warn($message) : $c->log->info($message);

            $c->response->redirect(
                $c->uri_for(
                    $c->controller('Administration')->action_for('index')
                )
            );
            return;
        }

        $c->stash(
            error         => 'BAD_LOGIN',
            error_message => 'The username or password was not accepted.',
        );
    }
    elsif ($submitted) {
        $c->stash(
            error         => 'EMPTY_LOGIN',
            error_message => 'Enter both a username and password.',
        );
    }

    $c->stash( template => 'administration/login.tt' );
    return;
}

=head2 entra

Start the Microsoft Entra authorization-code flow. The target URL is fixed to
an internal action so request parameters cannot create an open redirect.

=cut

sub entra : Path('entra') : Args(0) {
    my ( $self, $c ) = @_;

    $self->_set_no_store($c);
    my $config = $self->_entra_config($c);
    return $self->_render_login_error(
        $c,
        'Microsoft staff sign-in is not configured on this server.',
        404,
    ) unless $config->{enabled};

    $c->oidc('ENTRA')->delete_stored_data();
    $c->oidc('ENTRA')->redirect_to_authorize(
        target_url => $c->uri_for('/administration/login/entra/complete')->as_string,
    );
    return;
}

=head2 entra_complete

Convert a verified Entra identity into an Entra-managed Libki shadow account,
then establish the normal Libki authorization session.

=cut

sub entra_complete : Path('entra/complete') : Args(0) {
    my ( $self, $c ) = @_;

    $self->_set_no_store($c);
    my $config = $self->_entra_config($c);
    return $self->_render_login_error(
        $c,
        'Microsoft staff sign-in is not configured on this server.',
        404,
    ) unless $config->{enabled};

    my $identity = eval { $c->oidc('ENTRA')->get_valid_identity() };
    if ( !$identity ) {
        $c->log->warn('Entra completion reached without a valid stored identity');
        return $self->_render_login_error(
            $c,
            'Microsoft sign-in could not be completed. Please try again.',
            401,
        );
    }

    my $claims = $identity->claims;
    $c->oidc('ENTRA')->delete_stored_data();
    delete $c->session->{oidc_auth};
    unless ( ($claims->{exp} // 0) =~ /\A[0-9]+\z/ && $claims->{exp} > time ) {
        return $self->_render_login_error($c, 'Microsoft sign-in has expired. Please try again.', 401);
    }
    my $decision = Libki::Auth::Entra->authorization_from_claims(
        $identity->claims,
        $config,
    );

    if ( !$decision->{authorized} ) {
        eval { $c->oidc('ENTRA')->delete_stored_data() };
        my $reason = $decision->{reason} // 'unknown';
        $c->log->warn("Entra staff authorization denied: $reason");
        return $self->_render_login_error(
            $c,
            'Your Microsoft account is not assigned to Libki staff access.',
            403,
        );
    }

    my $user = eval { Libki::Auth::Entra->sync_user( $c, $decision ) };
    if ( !$user ) {
        $c->log->error('Entra shadow-account synchronization failed');
        eval { $c->oidc('ENTRA')->delete_stored_data() };
        return $self->_render_login_error(
            $c,
            'Your Microsoft account was verified, but Libki could not prepare the staff session.',
            500,
        );
    }

    my $auth_user = eval {
        $c->find_user(
            {
                instance => $c->instance,
                username => $decision->{username},
            }
        );
    };
    if ( !$auth_user ) {
        $c->log->error('Entra authentication-wrapper preparation failed');
        eval { $c->oidc('ENTRA')->delete_stored_data() };
        return $self->_render_login_error(
            $c,
            'Your Microsoft account was verified, but Libki could not prepare the staff session.',
            500,
        );
    }

    Libki::Auth::Session->rotate_id($c);
    my $session_established = eval {
        $c->set_authenticated($auth_user);
        1;
    };
    if ( !$session_established ) {
        $c->log->error('Entra authenticated-session establishment failed');
        eval { $c->logout };
        eval { $c->oidc('ENTRA')->delete_stored_data() };
        return $self->_render_login_error(
            $c,
            'Your Microsoft account was verified, but Libki could not prepare the staff session.',
            500,
        );
    }

    $c->session->{staff_display_name} = $decision->{display_name};
    $c->session->{staff_email}        = $decision->{email};
    $c->session->{staff_auth_source}  = 'Microsoft Entra ID';
    $c->session->{staff_entra_oid}    = $decision->{oid};
    $c->session->{staff_role_level}   = $decision->{role_level};
    $c->session->{staff_entra_expires_at} = $claims->{exp};

    $c->model('DB::Statistic')->create(
        {
            action     => 'ADMIN_LOGIN',
            created_on => $c->now,
            instance   => $c->instance,
            session_id => $c->sessionid,
            username   => $decision->{username},
            info       => to_json(
                {
                    auth_source         => 'entra',
                    role_level          => $decision->{role_level},
                    authorization_source => $decision->{authorization_source},
                    oid                 => $decision->{oid},
                }
            ),
        }
    );

    $c->log->info("Entra administration login established for $decision->{username}");
    $c->response->redirect( $c->uri_for('/administration') );
    return;
}

=head2 entra_error

Render a generic error after the OIDC plugin rejects a provider response. Raw
provider errors are intentionally not displayed in the browser.

=cut

sub entra_error : Path('entra/error') : Args(0) {
    my ( $self, $c ) = @_;

    $self->_set_no_store($c);
    delete $c->flash->{error_message} if $c->can('flash');
    $c->log->warn('Microsoft Entra authentication callback failed validation');
    return $self->_render_login_error(
        $c,
        'Microsoft sign-in could not be completed. Please try again or contact Information Technology.',
        401,
    );
}

=head2 signed_out

Show a landing page without automatically restarting Microsoft sign-in.

=cut

sub signed_out : Path('signed-out') : Args(0) {
    my ( $self, $c ) = @_;
    $self->_set_no_store($c);
    $c->stash(
        entra_sso_enabled => $self->_entra_config($c)->{enabled} ? 1 : 0,
        template => 'administration/signed_out.tt',
    );
}

sub _entra_config {
    my ( $self, $c ) = @_;
    return $c->config->{'Libki::Entra'} || { enabled => 0 };
}

sub _render_login_error {
    my ( $self, $c, $message, $status ) = @_;
    $c->response->status($status) if $status;
    $c->stash(
        entra_sso_enabled => $self->_entra_config($c)->{enabled} ? 1 : 0,
        entra_error_mode  => 1,
        error_message     => $message,
        template          => 'administration/login.tt',
    );
    return;
}

sub _set_no_store {
    my ( $self, $c ) = @_;
    $c->response->headers->header( 'Cache-Control' => 'no-store' );
    $c->response->headers->header( 'Pragma'        => 'no-cache' );
    $c->response->headers->header( 'Referrer-Policy' => 'no-referrer' );
    return;
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

This file is part of Libki.

Libki is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

=cut

__PACKAGE__->meta->make_immutable;

1;
