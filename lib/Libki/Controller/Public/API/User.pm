package Libki::Controller::Public::API::User;

use Moose;
use namespace::autoclean;

use Libki::Utils::Printing;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::DataTables - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for returning data about the logged in user

=head1 METHODS


=head2 funds

Returns the users current amount of funds for printing

=cut

sub funds : Local Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    if ( !$c->user_exists ) {
        $c->response->body('Unauthorized');
        $c->response->status(401);
        return;
    }

    my $user = $c->user();
    $user->discard_changes();

    delete $c->stash->{$_} for keys %{$c->stash};
    $c->stash(
        {
            funds => $user->funds
        }
    );
    $c->forward( $c->view('JSON') );
}

=head2 release_print_job

Sends the given print job to the actual print management backend.

=cut

sub release_print_job : Local : Args(0) {
    my ( $self, $c ) = @_;

    if ( !$c->user_exists ) {
        $c->response->body('Unauthorized');
        $c->response->status(401);
        return;
    }

    my $id = $c->request->params->{id};
    my $printer = $c->request->params->{printer};

    my $user = $c->user();

    my $data = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id => $id,
            user         => $user,
            printer      => $printer,
        }
    );

    delete $c->stash->{Settings};
    $c->stash( $data );

    $c->forward( $c->view('JSON') );
}

=head2 cancel_print_job

Sets the given print job status to Canceled

=cut

sub cancel_print_job : Local : Args(0) {
    my ( $self, $c ) = @_;

    if ( !$c->user_exists ) {
        $c->response->body('Unauthorized');
        $c->response->status(401);
        return;
    }

    my $id = $c->request->params->{id};

    my $user = $c->user();

    my $data = Libki::Utils::Printing::cancel( $c, $id, $user );
    delete $c->stash->{Settings};
    $c->stash( $data );

    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

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

__PACKAGE__->meta->make_immutable;

1;
