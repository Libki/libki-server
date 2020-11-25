package Libki::Controller::Public;

use Moose;
use namespace::autoclean;

use Libki::Utils::Printing;
BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Public - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path {
    my ( $self, $c, $tab ) = @_;

    my $instance = $c->instance;

    $tab ||= 'clients';
    $tab = 'clients' if $tab ne 'printing';

    $c->stash(
        tab => $tab,
        CustomJsPublic => $c->setting('CustomJsPublic'),
    );
}

=head2 upload_print_file

=cut

sub upload_print_file :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user();
    my $print_file = $c->req->upload('print_file');
    my $printer_id  = $c->req->params->{printer_id};

    Libki::Utils::Printing::create_print_job_and_file($c, {
        client_name => Libki::Utils::Printing::PRINT_FROM_WEB,
        copies      => 1,
        print_file  => $print_file,
        printer_id  => $printer_id,
        user        => $user,
        username    => $user->username,
    });

    $c->response->redirect( $c->uri_for('/public/printing') );
}

=head2 auto
    
Check if there is an authorized user and, if not, forward to login page
    
=cut

# Note that 'auto' runs after 'begin' but before your actions and that
# 'auto's "chain" (all from application path to most specific class are run)
# See the 'Actions' section of 'Catalyst::Manual::Intro' for more info.
sub auto : Private {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my @locations = $c->model('DB::Client')->search(
        {
            instance => $instance,
        },
        {
            columns  => [qw/location/],
            distinct => 1
        }
    )->get_column('location')->all();

    $c->stash( 
        interface => 'public',
        locations => \@locations,
    );
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
