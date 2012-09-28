package Libki::Controller::Administration::API::User;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 delete

=cut

sub delete : Local : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $user = $c->model('DB::User')->find($id);
    my $success = 0;
    
    if ( $user->delete() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

libki,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
