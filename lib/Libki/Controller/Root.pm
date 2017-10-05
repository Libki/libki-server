package Libki::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Libki::Controller::Root - Root Controller for Libki

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->go( 'Libki::Controller::Public', 'index' );
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.
Set the desired language.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    my $lang = $c->session->{lang};
    $c->languages([$lang]) if $lang;
}

=head2 auto
    
Stash all the system settings
    
=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my @settings = $c->model('DB::Setting')->search({ instance => $instance });
    my %s = map { $_->name() => $_->value() } @settings;
    $c->stash( 'Settings' => \%s );
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
