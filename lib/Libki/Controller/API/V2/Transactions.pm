package Libki::Controller::API::V2::Transactions;

use Moose;
use namespace::autoclean;

with 'Libki::Controller::API::V2::Role::Authorization';

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(
    namespace => 'api/v2/transactions',
);

use POSIX qw(round);

=head1 NAME

Libki::Controller::API::V2::Transactions - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for financial transactions in Libki

=head1 METHODS

=cut

=head2 list

/api/v2/transactions?user_id=1&

Returns JSON listing user's transactions; if user_id param is not specified, shows transactions for currently logged-in user

=cut

sub list : Path('') Args(0) Method('GET') {
    my ( $self, $c ) = @_;

    my $user_id  = $c->request->params->{user_id};
    # if no user_id param passed, and there is an authenticated user, assume we mean them
    if (!$user_id && $c->user) {
       $user_id = $c->user->id;
    }
    # Validate user existence
    return unless $self->_verify_user_existence( $c, $user_id);
    # Only the user themselves and admin can view the tranactions list
    return unless $self->_authorize_user_or_admin( $c, $user_id );

    my $instance = $c->instance;

    my %search = ( instance => $instance );
    $search{user_id} = $user_id if $user_id;

    my @rows = $c->model('DB::Transaction')->search(
        \%search,
        { order_by => { -desc => 'created_on' } }
    );

    my @data = map {
        {
            id          => $_->id,
            user_id     => $_->user_id,
            provider    => $_->provider,
            amount      => $_->amount_cents / 100,
            status      => $_->status,
            created_on  => $_->created_on . '',
        }
    } @rows;

    $c->stash('data' => \@data);
    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head2 cash_credit

/api/v2/transactions/cash/credit

Adds a cash credit transaction to the user. Accepts POST data with amount, user_id, and notes

=cut

sub cash_credit : Path('cash/credit') Args(0) Method('POST') {
    my ( $self, $c ) = @_;

    my $p = $c->request->body_data;
    my $user_id = $p->{user_id};

    # Validate user existence
    return unless $self->_verify_user_existence( $c, $user_id);
    # Permissions check; only admin can add cash credit
    return unless $self->_authorize_admin_only($c);

    # Validate amount given
    return unless $self->_validate_positive_amount($c, $p->{amount});
    my $amount_cents = round( $p->{amount} * 100 );

    my $txn = $c->model('DB::Transaction')->create({
        instance     => $c->instance,
        user_id      => $user_id,
        provider     => 'cash',
        amount_cents => $amount_cents,
        currency     => 'USD',
        status       => 'succeeded',
        notes        => $p->{notes},
    });

    $c->response->status(201);
    $c->stash(
            transaction_id => $txn->id,
            balance        => $txn->user->funds,
    );
    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head2 cash_debit

/api/v2/transactions/cash/debit

Adds a cash debit transaction to the user. Accepts POST data with amount, user_id, and notes

=cut


sub cash_debit : Path('cash/debit') Args(0) Method('POST') {
    my ( $self, $c ) = @_;

    my $p = $c->request->body_data;
    my $user_id = $p->{user_id};
    # Validate user existence
    return unless $self->_verify_user_existence( $c, $user_id);
    # Permissions check; only admin can add cash debits
    return unless $self->_authorize_admin_only($c);

    # Validate amount given
    return unless $self->_validate_positive_amount($c, $p->{amount});
    my $amount_cents = round( $p->{amount} * 100 );

    my $txn = $c->model('DB::Transaction')->create({
        instance     => $c->instance,
        user_id      => $user_id,
        provider     => 'cash',
        amount_cents => -$amount_cents,
        currency     => 'USD',
        status       => 'succeeded',
        notes        => $p->{notes},
    });

    $c->response->status(201);
    $c->stash(
            transaction_id => $txn->id,
            balance        => $txn->user->funds,
    );
    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

sub _validate_positive_amount {
    my ( $self, $c, $amount ) = @_;
    delete $c->stash->{Settings};

    unless ( defined $amount ) {
        $c->response->status(400);
        $c->stash->{json} = {
            error => 'amount is required',
        };
        $c->forward('View::JSON');
        return;
    }

    unless ( $amount =~ /^\d+(?:\.\d{1,2})?$/ ) {
        $c->response->status(400);
        $c->stash->{json} = {
            error => 'amount must be a positive number',
        };
        $c->forward('View::JSON');
        return;
    }

    if ( $amount <= 0 ) {
        $c->response->status(400);
        $c->stash->{json} = {
            error => 'amount must be greater than zero',
        };
        $c->forward('View::JSON');
        return;
    }

    return 1;
}



__PACKAGE__->meta->make_immutable;
1;
