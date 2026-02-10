package Libki::Payments::Stripe;

use Moose;
use namespace::autoclean;
use Data::Dumper;
use Digest::SHA qw(hmac_sha256_hex);
use Time::HiRes qw(time);

with 'Libki::Payments::Provider';

use POSIX qw(round);

=head2 create_checkout

Creates Payment Intent with Stripe for the given user and amount.
Logs pending transaction and updates with provider-given ID value.
Returns client_secret and transaction

=cut

sub create_checkout {
    require Net::Stripe;

    my ( $self, %args ) = @_;

    my $c        = $args{c};
    my $user     = $args{user};
    my $amount   = $args{amount};
    my $instance = $args{instance};

    my $cents = round( $amount * 100 );

    my $txn = $c->model('DB::Transaction')->create({
        instance     => $instance,
        user_id      => $user->id,
        provider     => 'stripe',
        amount_cents => $cents,
        currency     => 'USD',
        status       => 'created',
    });

    my $stripe = Net::Stripe->new(
        api_key => $c->setting('StripeSecretKey'),
        api_version => '2020-03-02'
    );

    # ---- Create PaymentIntent ----
    my $intent = $stripe->create_payment_intent({
        amount   => $cents,
        currency => 'usd',
        description => 'Libki Account Transaction',

#        automatic_payment_methods => {
#            enabled => \1,
#        },

        metadata => {
            transaction_id => $txn->id,
            user_id        => $user->id,
            instance       => $instance,
        },
    });

    $txn->update({
        provider_payment_id => $intent->id,
        status              => 'pending',
    });

    return {
        client_secret => $intent->client_secret,
        transaction  => $txn,
    };
}

=head2 handle_webhook

Receives incoming webhook call from Stripe with payload and signature.
Updates transaction from pending to successful or failed

=cut

sub handle_webhook {
    my ( $self, %args ) = @_;

    my $data = $args{data};
    my $c    = $args{c};

    my $event_type = $data->{type} // '';
    my $object     = $data->{data}{object} // {};

    return 1 unless $object->{id};

    my $pi_id = $object->{id};

    my $txn = $c->model('DB::Transaction')->find({
        provider            => 'stripe',
        provider_payment_id => $pi_id,
    });

    unless ($txn) {
        $c->log->warn("Stripe webhook: no transaction for $pi_id");
        return 1;
    }

    # Idempotency: don't touch terminal states
    return 1 if $txn->status =~ /^(succeeded|failed|cancelled)$/;

    if ( $event_type eq 'payment_intent.succeeded' ) {

        $txn->update({
            status => 'succeeded',
        });

    }
    elsif ( $event_type eq 'payment_intent.payment_failed' ) {

        my $reason =
            $object->{last_payment_error}{message}
            || 'Payment failed';

        $txn->update({
            status        => 'failed',
            failure_reason => $reason,
        });

    }
    elsif ( $event_type eq 'payment_intent.canceled' ) {

        $txn->update({
            status => 'cancelled',
        });
    }

    return 1;
}

=head2 verify_webhook_signature

    my $ok = $self->verify_webhook_signature(
        payload   => $raw_body,
        signature => $stripe_signature_header,
        secret    => $signing_secret,
        tolerance => 300,   # optional, in seconds
    );

Verifies the authenticity of a Stripe webhook request.

This method implements Stripe’s recommended webhook verification procedure.
It ensures that the request payload was sent by Stripe and has not been
tampered with in transit.

The verification process consists of the following steps:

=over 4

=item 1. Extract timestamp and signatures

The C<Stripe-Signature> header is parsed to extract:

=over 4

=item *

The timestamp (prefix C<t>)

=item *

One or more HMAC signatures (prefix C<v1>)

=back

All other signature versions are ignored.

=item 2. Construct the signed payload

A signed payload string is constructed by concatenating:

    "<timestamp>.<raw_request_body>"

The raw request body must be used exactly as received, without any decoding
or re-encoding, or the signature check will fail.

=item 3. Compute the expected signature

An HMAC-SHA256 digest is computed using the webhook signing secret as the key
and the signed payload as the message. The resulting digest is hex-encoded.

=item 4. Compare signatures securely

The computed signature is compared against each received C<v1> signature using
a constant-time comparison (see L</_secure_compare>) to prevent timing attacks.

=item 5. Validate timestamp tolerance

The timestamp is compared against the current system time. If the absolute
difference exceeds the configured tolerance (default: 300 seconds), the
signature is rejected to protect against replay attacks.

=back

The method returns true if the signature is valid and within tolerance.
If verification fails at any step, the method returns false.

This method does not throw exceptions and is safe to call directly from a
webhook controller. Callers should return an HTTP 400 or 401 response when
verification fails.

=cut


sub verify_webhook_signature {
    my ( $self, %args ) = @_;

    my $payload    = $args{payload};          # raw request body (string)
    my $sig_header = $args{signature};        # Stripe-Signature header
    my $secret     = $args{secret};           # StripeWebhookSigningSecret
    my $tolerance  = $args{tolerance} // 300; # 5 minutes

    return 0 unless $payload && $sig_header && $secret;

    # Step 1: parse header
    my ( $timestamp, @signatures );

    for my $part ( split /,/, $sig_header ) {
        my ( $k, $v ) = split /=/, $part, 2;
        next unless defined $k && defined $v;

        if ( $k eq 't' ) {
            $timestamp = $v;
        }
        elsif ( $k eq 'v1' ) {
            push @signatures, $v;
        }
    }

    return 0 unless $timestamp && @signatures;

    # Step 2: prepare signed payload
    my $signed_payload = "$timestamp.$payload";

    # Step 3: compute expected signature
    my $expected = hmac_sha256_hex( $signed_payload, $secret );

    # Step 4: constant-time comparison
    for my $sig (@signatures) {
        return 1
          if _secure_compare( $expected, $sig )
          && abs( time() - $timestamp ) <= $tolerance;
    }

    return 0;
}

=head2 _secure_compare

    my $ok = _secure_compare( $expected, $received );

Performs a constant-time comparison of two strings.

This function is used to compare cryptographic signatures (such as Stripe
webhook signatures) in a way that prevents timing attacks. A timing attack
occurs when an attacker can infer information about a secret value by measuring
how long comparisons take to fail.

Unlike a simple string comparison (C<eq>), which may return early on the first
mismatched character, this function always compares every character in both
strings and accumulates the differences. The execution time therefore depends
only on the length of the strings, not on how similar they are.

The function returns true if and only if:

=over 4

=item *

Both values are defined

=item *

Both values are the same length

=item *

All corresponding characters match exactly

=back

This approach is recommended by Stripe and other payment providers when
verifying webhook signatures or any HMAC-based authentication data.

=cut

sub _secure_compare {
    my ( $a, $b ) = @_;
    return 0 unless defined $a && defined $b;
    return 0 unless length($a) == length($b);

    my $diff = 0;
    for ( my $i = 0 ; $i < length($a) ; $i++ ) {
        $diff |= ord( substr( $a, $i, 1 ) ) ^ ord( substr( $b, $i, 1 ) );
    }
    return $diff == 0;
}



=head1 AUTHOR

Ian Walls <ian@bywatersolutions.com>

=cut

=head1 LICENSE
This file is part of Libki.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut


1;
