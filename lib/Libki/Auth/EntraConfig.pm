package Libki::Auth::EntraConfig;
use strict;
use warnings;
use Carp qw(croak);

=head1 NAME

Libki::Auth::EntraConfig - optional single-tenant staff authentication settings

=head1 METHODS

=head2 from_env

Build Libki authorization and OIDC client settings from an environment hash.
Disabled installations require no tenant registration or credentials.

=cut

sub from_env {
    my ( $class, $env ) = @_;
    my $entra_enabled = ( $env->{LIBKI_ENTRA_ENABLED} // q{} ) =~ /\A(?:1|true|yes|on)\z/i
        ? 1
        : 0;

    my $entra_config = {
        enabled        => 0,
        admin_app_role => $env->{LIBKI_ENTRA_ADMIN_APP_ROLE} // 'Libki.Admin',
        staff_app_role => $env->{LIBKI_ENTRA_STAFF_APP_ROLE} // 'Libki.Staff',
    };
    my $oidc_client_config = {
        authentication_error_path => '/administration/login/entra/error',
        provider                  => {},
    };

    if ($entra_enabled) {
        for my $required (qw/LIBKI_ENTRA_TENANT_ID LIBKI_ENTRA_CLIENT_ID OIDC_ENTRA_SECRET/) {
            croak "$required is required when LIBKI_ENTRA_ENABLED is true"
                unless defined( $env->{$required} ) && $env->{$required} =~ /\S/;
        }

        my $tenant_id = lc $env->{LIBKI_ENTRA_TENANT_ID};
        my $client_id = lc $env->{LIBKI_ENTRA_CLIENT_ID};
        my $guid_pattern = qr/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/;
        croak 'LIBKI_ENTRA_TENANT_ID must be a GUID' unless $tenant_id =~ $guid_pattern;
        croak 'LIBKI_ENTRA_CLIENT_ID must be a GUID' unless $client_id =~ $guid_pattern;

        for my $key (qw/LIBKI_ENTRA_ADMIN_GROUP_ID LIBKI_ENTRA_STAFF_GROUP_ID/) {
            croak "$key must be a GUID"
                if length( $env->{$key} // q{} ) && lc($env->{$key}) !~ $guid_pattern;
        }

        $entra_config = {
            %{$entra_config},
            enabled        => 1,
            tenant_id      => $tenant_id,
            client_id      => $client_id,
            admin_group_id => lc( $env->{LIBKI_ENTRA_ADMIN_GROUP_ID} // q{} ),
            staff_group_id => lc( $env->{LIBKI_ENTRA_STAFF_GROUP_ID} // q{} ),
        };
        $oidc_client_config->{default_provider} = 'ENTRA';
        $oidc_client_config->{provider}->{ENTRA} = {
            id                         => $client_id,
            secret                     => $env->{OIDC_ENTRA_SECRET},
            well_known_url             => "https://login.microsoftonline.com/$tenant_id/v2.0/.well-known/openid-configuration",
            signin_redirect_path       => '/oidc/entra/callback',
            scope                      => 'openid profile email',
            store_mode                 => 'session',
            use_pkce                   => 1,
            pkce_code_challenge_method => 'S256',
            expiration_leeway          => 60,
            max_id_token_age           => 600,
            client_auth_method         => 'client_secret_post',
        };
    }

    return ($entra_config, $oidc_client_config);
}


=head1 LICENSE

This file is part of Libki and is licensed under the GNU Affero General Public
License version 3 or, at your option, any later version.

=cut

1;
