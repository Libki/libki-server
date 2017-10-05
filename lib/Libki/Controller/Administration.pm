package Libki::Controller::Administration;
use Moose;
use namespace::autoclean;

use Encode qw(decode encode);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    my @locations = $c->model('DB::Client')->search(
        {
            instance => $instance,
        },
        {
            columns  => decode('UTF-8',[qw/location/]),
            distinct => 1
        }
    )->get_column('location')->all();

    $c->stash(
        DefaultTimeAllowance => $c->setting('DefaultTimeAllowance'),
        CustomJsAdministration => $c->setting('CustomJsAdministration'),
        locations => \@locations,
    );
}

=head2 auto
    
Check if there is an authorized user and, if not, forward to login page
    
=cut

# Note that 'auto' runs after 'begin' but before your actions and that
# 'auto's "chain" (all from application path to most specific class are run)
# See the 'Actions' section of 'Catalyst::Manual::Intro' for more info.
sub auto : Private {
    my ( $self, $c ) = @_;

    $c->stash( interface => 'administration' );
    
    # Allow unauthenticated users to reach the login page.  This
    # allows unauthenticated users to reach any action in the Login
    # controller.  To lock it down to a single action, we could use:
    #   if ($c->action eq $c->controller('Login')->action_for('index'))
    # to only allow unauthenticated access to the 'index' action we
    # added above.
    if ( $c->controller eq $c->controller('Administration::Login') ) {
        return 1;
    }

    if ( $c->user_exists ) {
        if ( $c->check_user_roles('admin') ) {
            return 1;
        }
        else {
            $c->response->body('Unauthorized!');
        }
    }
    else {    # If a user doesn't exist, force login
              # Redirect the user to the login page
        $c->response->redirect( $c->uri_for('/administration/login') );

      # Return 0 to cancel 'post-auto' processing and prevent use of application
        return 0;
    }

}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

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
