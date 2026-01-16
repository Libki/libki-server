package Libki::Controller::API::V2::Role::Authorization;

use Moose::Role;

=head1 NAME

Libki::Controller::API::V2::Role::Authorization

=head1 DESCRIPTION

Reusable authorization helpers for API v2 controllers.

=cut

sub _require_login {
    my ( $self, $c ) = @_;

    return 1 if $c->user;

    $c->response->status(401);
    $c->stash->{json} = { error => 'authentication required' };
    delete $c->stash->{Settings};
    $c->forward('View::JSON');
    return 0;
}

sub _authorize_user_or_admin {
    my ( $self, $c, $target_user_id ) = @_;

    return unless $self->_require_login($c);

    my $actor = $c->user;

    return 1 if $c->check_any_user_role( $actor, qw/admin superadmin/ );

    if ( defined $target_user_id && $target_user_id != $actor->id ) {
        $c->response->status(403);
        delete $c->stash->{Settings};
        $c->stash->{json} = { error => 'insufficient privileges' };
        $c->forward('View::JSON');
        return 0;
    }

    return 1;
}

sub _authorize_admin_only {
    my ( $self, $c ) = @_;

    return unless $self->_require_login($c);

    return 1 if $c->check_any_user_role( $c->user, qw/admin superadmin/ );

    $c->response->status(403);
    delete $c->stash->{Settings};
    $c->stash->{json} = { error => 'admin privileges required' };
    $c->forward('View::JSON');
    return 0;
}

sub _verify_user_existence {
    my ( $self, $c, $user_id ) = @_;

    my $user = $c->model('DB::User')->find($user_id);

    unless ($user) {
        $c->response->status(404);
        $c->stash->{json} = {
            error => 'user not found',
        };
        delete $c->stash->{Settings};
        $c->forward('View::JSON');
        return 0;
    }
    return 1;
}

1;
