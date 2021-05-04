package Libki::Controller::API::Public;

use Moose;
use namespace::autoclean;

use Libki::Auth qw(authenticate_user);

BEGIN { extends 'Catalyst::Controller'; }

use JSON;

use Libki::Auth;

=head1 NAME

Libki::Controller::API::Public - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 authenticate

/api/public/authenticate/<api_key>?username=admin&password=mypass

Returns JSON with keys for success and error.

=cut

sub authenticate : Local : Args(1) {
    my ( $self, $c, $api_key ) = @_;

    my $api_key_validated = Libki::Auth::validate_api_key(
        {
            context => $c,
            key     => $api_key,
            type    => '*',
        }
    );

    my $username = $c->request->params->{'username'};
    my $password = $c->request->params->{'password'};

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
        $c->stash(
            success => JSON::false,
            error   => "Invalid API key.",
        );
    }
    else {
        $c->stash(
            success => JSON::false,
            error   => "Parameters username and password are required.",
        );
    }

    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

__PACKAGE__->meta->make_immutable;

1;
