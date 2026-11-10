# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
package Libki::ScreenViewer;

use strict;
use warnings;

use Carp qw(croak);
use Digest::SHA qw(hmac_sha256_hex);
use Exporter qw(import);

our @EXPORT_OK = qw(config_from_env mint_token normalize_reason viewer_reasons);

my @VIEWER_REASON_CODES = qw(
    patron_assistance
    technical_troubleshooting
    policy_safety_review
    accessibility_assistance
);

my %VIEWER_REASON_LABELS = (
    patron_assistance         => 'Patron requested assistance',
    technical_troubleshooting => 'Technical troubleshooting',
    policy_safety_review      => 'Computer-use policy or safety review',
    accessibility_assistance  => 'Accessibility assistance',
);

sub viewer_reasons {
    return map {
        {
            code  => $_,
            label => $VIEWER_REASON_LABELS{$_},
        }
    } @VIEWER_REASON_CODES;
}

sub normalize_reason {
    my ($reason_code) = @_;

    $reason_code //= q{};
    croak 'a supported screen-view reason is required'
        unless exists $VIEWER_REASON_LABELS{$reason_code};

    return {
        code  => $reason_code,
        label => $VIEWER_REASON_LABELS{$reason_code},
    };
}

sub config_from_env {
    my ($env) = @_;
    $env ||= \%ENV;

    my $enabled = ( $env->{LIBKI_VIEWER_ENABLED} // q{} )
        =~ /\A(?:1|true|yes|on)\z/i ? 1 : 0;

    return { enabled => 0, clients => {} } unless $enabled;

    for my $required (
        qw/LIBKI_VIEWER_ORIGIN LIBKI_VIEWER_CLIENT_NAME LIBKI_VIEWER_HMAC_FILE LIBKI_VIEWER_PASSWORD_FILE/
      )
    {
        croak "$required is required when LIBKI_VIEWER_ENABLED is true"
            unless defined( $env->{$required} ) && $env->{$required} =~ /\S/;
    }

    my $instance = $env->{LIBKI_VIEWER_INSTANCE} // q{};
    croak 'LIBKI_VIEWER_INSTANCE contains unsupported characters'
        unless $instance =~ /\A[A-Za-z0-9_.-]{0,64}\z/;
    my $origin = $env->{LIBKI_VIEWER_ORIGIN};
    croak 'LIBKI_VIEWER_ORIGIN must be an HTTPS origin without a path'
        unless $origin =~ m{\Ahttps://[A-Za-z0-9.-]+(?::[0-9]{1,5})?\z};
    my $client_name = $env->{LIBKI_VIEWER_CLIENT_NAME};
    croak 'LIBKI_VIEWER_CLIENT_NAME contains unsupported characters'
        unless $client_name =~ /\A[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\z/;

    my $hmac_secret = _read_secret(
        $env->{LIBKI_VIEWER_HMAC_FILE},
        'viewer HMAC secret',
        32,
        4096,
    );
    my $vnc_password = _read_secret(
        $env->{LIBKI_VIEWER_PASSWORD_FILE},
        'viewer VNC password',
        6,
        8,
    );
    croak 'viewer VNC password must contain printable non-whitespace ASCII only'
        unless $vnc_password =~ /\A[!-~]{6,8}\z/;

    return {
        enabled     => 1,
        origin      => $origin,
        instance    => $instance,
        hmac_secret => $hmac_secret,
        token_ttl   => 60,
        clients     => {
            $client_name => {
                password => $vnc_password,
            },
        },
    };
}

sub mint_token {
    my ( $config, $client_name, $now ) = @_;

    croak 'screen viewer is not enabled'
        unless $config && $config->{enabled};
    croak 'screen viewer client is not allowed'
        unless defined($client_name) && $config->{clients}->{$client_name};

    $now = time() unless defined $now;
    my $expires = int($now) + ( $config->{token_ttl} // 60 );
    my $nonce   = unpack( 'H*', _secure_random(16) );
    my $payload = join q{.}, $client_name, $expires, $nonce;
    my $signature = hmac_sha256_hex( $payload, $config->{hmac_secret} );

    return "$payload.$signature";
}

sub _read_secret {
    my ( $path, $label, $minimum, $maximum ) = @_;

    open my $fh, '<:raw', $path
        or croak "cannot open $label file: $!";
    local $/;
    my $value = <$fh>;
    close $fh or croak "cannot close $label file: $!";

    $value //= q{};
    $value =~ s/[\r\n]+\z//;
    my $length = length($value);
    croak "$label length is outside the allowed range"
        if $length < $minimum || $length > $maximum;

    return $value;
}

sub _secure_random {
    my ($length) = @_;

    open my $fh, '<:raw', '/dev/urandom'
        or croak "cannot open operating-system random source: $!";
    my $buffer = q{};
    while ( length($buffer) < $length ) {
        my $read = read $fh, my $chunk, $length - length($buffer);
        croak "cannot read operating-system random source: $!"
            unless defined $read;
        croak 'operating-system random source returned no data'
            if $read == 0;
        $buffer .= $chunk;
    }
    close $fh or croak "cannot close operating-system random source: $!";

    return $buffer;
}

1;

=head1 NAME

Libki::ScreenViewer - Configuration and signed tokens for the optional viewer

=head1 FUNCTIONS

=head2 config_from_env

Read viewer settings from the supplied hash reference (or the environment).
Return disabled configuration by default; reject invalid enabled settings.
Secrets are loaded from files and must not be logged or serialized.

=head2 viewer_reasons

Return the supported reason code/label pairs. All require endpoint approval.

=head2 normalize_reason

Validate a reason code and return its code/label pair, or throw an error.

=head2 mint_token

Sign the allowed client name, expiry and a fresh cryptographic nonce using the
configured HMAC key. The optional third argument supplies the current time.
Expiration limits connection startup, not an established viewing session.

=head1 LICENSE

AGPL-3.0-or-later. Copyright 2026 City of Clinton, Iowa.

=cut
