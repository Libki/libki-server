package Libki::Controller::API::V2::Transactions::Stripe;

use Moose;
use namespace::autoclean;
use JSON qw(decode_json);

use Libki::Payments::Stripe;

BEGIN { extends 'Libki::Controller::API::V2::Transactions'; }

__PACKAGE__->config(
    namespace => 'api/v2/transactions/stripe'
);

=head1 NAME

Libki::Controller::API::V2::Transactions::Stripe - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for Stripe transactions in Libki

=head1 METHODS

=cut

=head2 checkout

/api/v2/transactions/stripe/checkout?amount=0.01

Returns JSON client_secret and return_url

=cut

sub checkout : POST Path('checkout') Args(0) {
    my ( $self, $c ) = @_;

    my $amount = $c->request->params->{amount};

    return unless $self->_require_login($c);
    return unless $self->_validate_positive_amount($c, $amount);

    my $provider = Libki::Payments::Stripe->new;

    my $result = $provider->create_checkout(
        c        => $c,
        user     => $c->user,
        amount   => $amount,
        instance => $c->instance,
    );

    $c->stash(
        client_secret => $result->{client_secret},
        return_url    => $c->uri_for('/account', { payment => 'processing' })->as_string,
    );

    $c->forward('View::JSON');
}

=head2 webhook

/api/v2/transactions/stripe/webhook

Accepts update on payment intent status

=cut

sub webhook : POST Path('webhook') Args(0) {
    my ( $self, $c ) = @_;

    my $body_fh = $c->request->body;
    my $payload = do { local $/; <$body_fh> };

    my $signature = $c->request->header('Stripe-Signature');

    my $provider = Libki::Payments::Stripe->new;

    unless (
        $provider->verify_webhook_signature(
            payload   => $payload,
            signature => $signature,
            secret    => $c->setting('StripeWebhookSigningSecret'),
        )
    ) {
        $c->log->warn('Stripe webhook: signature verification failed');
        $c->response->status(400);
        $c->response->body('invalid signature');
        return;
    }

    my $json_data;
    eval {
        $json_data = decode_json($payload);
        1;
    } or do {
        $c->log->error('Stripe webhook: invalid JSON');
        $c->response->status(400);
        $c->response->body('invalid payload');
        return;
    };

    $provider->handle_webhook(
        c    => $c,
        data => $json_data,
    );

    $c->response->status(200);
    $c->response->content_type('text/plain');
    $c->response->body('ok');
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

