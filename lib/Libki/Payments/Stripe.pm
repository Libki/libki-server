package Libki::Payments::Stripe;

use Moose;
use namespace::autoclean;

with 'Libki::Payments::Provider';

use POSIX qw(round);

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
        api_key => $c->setting('StripeSecretKey')
    );

    my $session = $stripe->checkout->sessions->create({
        mode => 'payment',
        success_url => $c->uri_for(
            '/account',
            { payment => 'success' }
        ),
        cancel_url => $c->uri_for(
            '/account',
            { payment => 'cancelled' }
        ),
        line_items => [{
            quantity => 1,
            price_data => {
                currency => 'usd',
                unit_amount => $cents,
                product_data => {
                    name => 'Libki Account Credit',
                },
            },
        }],
        metadata => {
            transaction_id => $txn->id,
            user_id        => $user->id,
            instance       => $instance,
        },
    });

    $txn->update({
        provider_payment_id => $session->id,
        status              => 'pending',
    });

    return {
        checkout_url => $session->url,
        transaction  => $txn,
    };
}

sub handle_webhook {
    require Net::Stripe;

    my ( $self, %args ) = @_;

    my $c = $args{c};

    my $payload   = $c->request->body_data;
    my $signature = $c->request->header('Stripe-Signature');

    my $event = Net::Stripe::Webhook::construct_event(
        $payload,
        $signature,
        $c->setting('StripeWebhookSigningSecret')
    );

    if ( $event->type eq 'checkout.session.completed' ) {
        my $session = $event->data->object;

        my $txn = $c->model('DB::Transaction')->find({
            provider => 'stripe',
            provider_payment_id => $session->id,
        });

        $txn->update({ status => 'succeeded' }) if $txn;
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
