package Libki::Payments::Stripe;

use Moose;
use namespace::autoclean;
use Data::Dumper;

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
