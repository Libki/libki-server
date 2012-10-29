package Libki::Controller::Administration::API::Client;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::Client - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 modify_time

=cut

sub modify_time : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $success = 0;

    my $client_id = $c->request->params->{'id'};
    my $minutes   = $c->request->params->{'minutes'};

    my $client = $c->model('DB::Client')->find($client_id);

    if ( defined($client) && defined( $client->session ) ) {
        my $user = $client->session->user;

        if ( $minutes =~ /^[+-]/ ) {
            $minutes = $user->minutes + $minutes;
        }

        $user->set_column( 'minutes', $minutes );

        if ( $user->update() ) {
            $success = 1;
        }
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 logout

=cut

sub logout : Local : Args(1) {
    my ( $self, $c, $client_id ) = @_;
    my $success = 0;

    my $client = $c->model('DB::Client')->find($client_id);

    if ( defined($client) && defined( $client->session ) ) {
        if ( $client->session->delete() ) {
            $success = 1;
        }
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
