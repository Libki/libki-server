package Libki::Controller::Administration::Logout;
use Moose;
use namespace::autoclean;


BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::Logout - staff logout controller

=head1 METHODS

=head2 index

Clear both the Libki authentication state and any OIDC token material retained
in the server-side session.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $entra_enabled = ($c->config->{'Libki::Entra'} || {})->{enabled};
    $c->logout;
    $c->delete_session('Staff logout');
    $c->_session_store_delegate(undef) if $c->can('_session_store_delegate');
    $c->response->headers->header( 'Cache-Control' => 'no-store' );
    $c->response->redirect( $c->uri_for(
        $entra_enabled ? '/administration/login/signed-out' : '/administration/login'
    ) );
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

=cut

__PACKAGE__->meta->make_immutable;

1;
