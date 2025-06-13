package Libki::Controller::API::Public;

use Moose;
use namespace::autoclean;

use Libki::Auth;

BEGIN { extends 'Catalyst::Controller'; }

use JSON;

use Libki::Auth;

=head1 NAME

Libki::Controller::API::Public - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 authenticate_user

/api/public/authenticate?api_key=API_KEY&username=admin&password=mypass

Returns JSON with keys for success and error.

=cut

sub authenticate_user : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $api_key  = $c->request->params->{'api_key'};
    my $username = $c->request->params->{'username'};
    my $password = $c->request->params->{'password'};

    my $api_key_validated = Libki::Auth::validate_api_key(
        {
            context => $c,
            key     => $api_key,
            type    => '*',
        }
    );

    $c->log()->debug("API::Public::authenticate( username => $username, username => $username");

    my $data =
      ( $api_key_validated && $username && $password )
      ? Libki::Auth::authenticate_user(
        {
            context  => $c,
            username => $username,
            password => $password,
        }
      )
      : undef;

    if ($data) {
        $c->stash(
            success => $data->{success} ? JSON::true : JSON::false,
            error   => $data->{error},
        );
    }
    elsif ( !$api_key_validated ) {
        $c->response->status(401);
        $c->stash(
            success => JSON::false,
            error   => "INVALID_API_KEY",
        );
    }
    else {
        $c->response->status(404);
        $c->stash(
            success => JSON::false,
            error   => "MISSING_PARAMETERS",
        );
    }

    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head2 user_funds

GET /api/public/funds?api_key=API_KEY&username=someuser

POST /api/public/funds/api_key=API_KEY&username=someuser&amount=1.25

Returns JSON with keys for success and error.

=cut

sub user_funds : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $api_key  = $c->request->params->{'api_key'};
    my $username = $c->request->params->{'username'};

    my $api_key_validated = Libki::Auth::validate_api_key(
        {
            context => $c,
            key     => $api_key,
            type    => '*',
        }
    );

    my $instance = $c->instance;
    my $user = $username ? $c->model('DB::User')->find({ instance => $instance, username => $username }) : undef;

    if ( !$api_key_validated ) {
        $c->response->status(401);
        $c->stash(
            success => JSON::false,
            error   => "INVALID_API_KEY",
        );
    } elsif ( !$user ) {
        $c->response->status(404);
        $c->stash(
            success => JSON::false,
            error   => "INVALID_USER",
        );
    } else {
        if ( $c->request->method eq 'GET' ) {
            $c->stash(
                success => JSON::true,
                balance => $user->funds,
            );
        } elsif ( $c->request->method eq 'POST' ) {
            my $funds = $c->request->params->{'funds'};

            $user->add_funds($funds);

            $c->stash(
                success => JSON::true,
                balance => $user->funds,
            );
        } else {
            $c->response->status(404);
            $c->stash(
                success => JSON::false,
                error   => "Invalid HTTP verb.",
            );
        }
    }

    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

__PACKAGE__->meta->make_immutable;

1;
