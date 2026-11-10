package Libki::Auth::Session;

use strict;
use warnings;

=head1 NAME

Libki::Auth::Session - authentication-boundary session helpers

=head1 METHODS

=head2 rotate_id

Rotate the Catalyst session ID and discard the stale cached DBIC delegate.
Catalyst::Plugin::Session::Store::DBIC 0.14 retains the row object that the
upstream C<change_session_id> method deletes. If that delegate reaches request
finalization, DBIx::Class attempts to update the deleted row and the request
fails. Dropping only the cached delegate allows the normal request finalizer to
persist the current session under the newly generated ID.

=cut

sub rotate_id {
    my ( $class, $c ) = @_;

    return unless $c && $c->can('change_session_id');

    my $new_id = $c->change_session_id;
    $c->_session_store_delegate(undef)
        if $c->can('_session_store_delegate');

    return $new_id;
}


=head1 LICENSE

This file is part of Libki and is licensed under the GNU Affero General Public
License version 3 or, at your option, any later version.

=cut

1;
