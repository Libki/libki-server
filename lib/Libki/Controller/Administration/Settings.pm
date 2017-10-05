package Libki::Controller::Administration::Settings;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::Settings - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 auto

=cut 

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/superadmin/ );    
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $settings = $c->model('DB::Setting')->search({ instance => $instance });
    
    while ( my $s = $settings->next() ) {
        $c->stash( $s->name => $s->value );
    }
}

=head2 update

=cut

sub update :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    foreach my $setting ( keys %{$c->request->params} ) {
        $c->model('DB::Setting')->update_or_create(
            {
                instance => $instance,
                name     => $setting,
                value    => $c->request->params->{ $setting },
            }
        );
    }
    
    $c->response->redirect( $c->uri_for( $self->action_for('index') ) );
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
