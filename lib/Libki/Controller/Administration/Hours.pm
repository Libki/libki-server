package Libki::Controller::Administration::Hours;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::Hours - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 auto

=cut 

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/admin/ );    
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(dates => [$c->model('DB::Closing_hours')->search({
    -not => [
      -or => [
        day => 'monday',
        day => 'tuesday',
        day => 'wednesday',
        day => 'thursday',
        day => 'friday',
        day => 'saturday',
        day => 'sunday',
      ],
    ],
    })]);

    my $days = $c->model('DB::Closing_hours')->search({
    -or => [
        day => 'monday',
        day => 'tuesday',
        day => 'wednesday',
        day => 'thursday',
        day => 'friday',
        day => 'saturday',
        day => 'sunday',
    ],
    });
    
    while ( my $day = $days->next() ) {
        $c->stash( $day->day => $day->closing_time );
    }
}

=head2 update

=cut

sub update :Local :Args(0) {
    my ( $self, $c ) = @_;

    foreach my $hour ( keys %{$c->request->params} ) { 
    
        if ($hour eq 'delete'){
            my $datevalue = $c->request->params->{ $hour };
            my $todelete = $c->model('DB::Closing_hours')->search({ day => $datevalue });
            $todelete->delete;
        }
        
        else {
            $c->model('DB::Closing_hours')->update_or_create(
                'day'  => $hour,
                'closing_time' => $c->request->params->{ $hour },
            );
        }
    }
    
    $c->response->redirect( $c->uri_for( $self->action_for('index') ) );

}


=head1 AUTHOR

Erik Öhrn <erik.ohrn@gmail.com>

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
