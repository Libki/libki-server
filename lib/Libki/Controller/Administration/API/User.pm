package Libki::Controller::Administration::API::User;

use Moose;
use String::Random qw(random_string);

use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 get

=cut

sub get : Local : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $user = $c->model('DB::User')->find($id);

    $c->stash(
        {
            'id'              => $user->id,
            'username'        => $user->username,
            'minutes'         => $user->minutes,
            'status'          => $user->status,
            'message'         => $user->message,
            'notes'           => $user->notes,
            'is_troublemaker' => $user->is_troublemaker,
        }
    );

    $c->forward( $c->view('JSON') );
}

=head2 create

=cut

sub create : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $params = $c->request->params;

    my $username = $params->{'username'};
    my $password = $params->{'password'};
    my $minutes  = $params->{'minutes'}
      || $c->model('DB::Setting')->find('DefaultTimeAllowance')->value;

    my $success = 0;

    my $user = $c->model('DB::User')->create(
        {
            username => $username,
            password => $password,
            minutes  => $minutes,
            status   => 'enabled',
        }
    );

    $success = 1 if ($user);

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 create_guest

=cut

sub create_guest : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $params = $c->request->params;

    my $current_guest_number_setting =
      $c->model('DB::Setting')->find('CurrentGuestNumber');
    my $current_guest_number = $current_guest_number_setting->value + 1;
    $current_guest_number_setting->set_column( 'value', $current_guest_number );
    $current_guest_number_setting->update();

    my $username = "guest" . $current_guest_number;
    my $password =
      random_string("nnnn");    #TODO: Make the pattern a system setting
    my $minutes = $c->model('DB::Setting')->find('DefaultTimeAllowance')->value;

    my $success = 0;

    my $user = $c->model('DB::User')->create(
        {
            username => $username,
            password => $password,
            minutes  => $minutes,
            status   => 'enabled',
        }
    );

    $success = 1 if ($user);

    $c->stash(
        'success'  => $success,
        'username' => $username,
        'password' => $password,
        'minutes'  => $minutes
    );
    $c->forward( $c->view('JSON') );
}

=head2 update

=cut

sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $success = 0;

    my $id      = $c->request->params->{'id'};
    my $minutes = $c->request->params->{'minutes'};
    my $notes   = $c->request->params->{'notes'};
    my $status  = $c->request->params->{'status'};

    my $user = $c->model('DB::User')->find($id);

    $user->set_column( 'minutes', $minutes );
    $user->set_column( 'notes',   $notes );
    $user->set_column( 'status',  $status );

    if ( $user->update() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 delete

=cut

sub delete : Local : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $user    = $c->model('DB::User')->find($id);
    my $success = 0;

    if ( $user->delete() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 is_username_unique

=cut

sub is_username_unique : Local : Args(1) {
    my ( $self, $c, $username ) = @_;

    my $count =
      $c->model('DB::User')->search( { username => $username } )->count();

    my $is_unique = ($count) ? 0 : 1;

    $c->stash( is_unique => $is_unique );

    $c->forward( $c->view('JSON') );
}

=head2 toggle_troublemaker

=cut

sub toggle_troublemaker : Local : Args(1) {
    my ( $self, $c, $id ) = @_;
    my $success = 0;

    my $user = $c->model('DB::User')->find($id);

    my $is_troublemaker = ( $user->is_troublemaker eq 'Yes' ) ? 'No' : 'Yes';

    $user->set_column( 'is_troublemaker', $is_troublemaker );

    if ( $user->update() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 change_password

=cut

sub change_password : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $success = 0;

    my $id       = $c->request->params->{'id'};
    my $password = $c->request->params->{'password'};

    my $user = $c->model('DB::User')->find($id);

    $user->set_column( 'password', $password );

    if ( $user->update() ) {
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
