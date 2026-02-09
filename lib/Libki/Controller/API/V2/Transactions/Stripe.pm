package Libki::Controller::API::V2::Transactions::Stripe;

use Moose;
use namespace::autoclean;

use Libki::Payments::Stripe;

BEGIN { extends 'Libki::Controller::API::V2::Transactions'; }

__PACKAGE__->config(
    namespace => 'api/v2/transactions/stripe'
);

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

sub webhook : POST Path('webhook') Args(0) {
    my ( $self, $c ) = @_;

    my $provider = Libki::Payments::Stripe->new;
    $provider->handle_webhook( c => $c );

    $c->response->status(200);
}

__PACKAGE__->meta->make_immutable;
1;

