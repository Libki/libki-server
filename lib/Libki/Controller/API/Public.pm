package Libki::Controller::API::Public;

use Moose;
use namespace::autoclean;

use Encode qw(decode encode);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::API::Public::Reservations - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 client

/api/public/client/TestClient?username=admin&password=mypass

returns JSON hash containing the username as a key value pair

=cut

sub client : Local : Args(1) {
    my ( $self, $c, $name ) = @_;

    my $instance = $c->instance;

    my $username = $c->request->params->{'username'};
    my $password = $c->request->params->{'password'};

    $c->log()->debug("API::Public::client( name => $name, username => $username, password => $password");

    delete $c->stash->{Settings};

    if (   $c->authenticate( { username => $username, password => $password } )
        && $c->check_user_roles(qw/admin/) )
    {

        my $client = $c->model('DB::Client')->single( { instance => $instance, name => $name } );

        if ($client) {
            my $session = $client->session();

            if ($session) {

                my $user = $session->user();

                $c->stash(
                    username   => $user->username(),
                    clientname => decode('UTF-8',$client->name()),
                    instance   => $instance,
                );
                $c->log()->debug( "API::Public::client returning ( username => " . $user->username() . ", clientname => " . $client->name() . " )" );

            }

        }

        if ( $name eq 'TEST_IN' ) {
            $c->stash( username => 'TEST_OUT', clientname => 'TEST_CLIENTNAME' );
            $c->log()->debug("API::Public::client returning ( username => TEST_OUT, clientname => TEST_CLIENTNAME ) for testing mode");
        }

    }
    else {
        $c->stash( error => 'authentication' );
    }

    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

__PACKAGE__->meta->make_immutable;

1;
