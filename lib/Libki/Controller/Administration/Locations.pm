package Libki::Controller::Administration::Locations;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

our @days_of_week =
  qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday );

=head1 NAME

Libki::Controller::Administration::Locations - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 auto

=cut 

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->assert_user_roles(qw/admin/);
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    # Get the list of locations
    my @locations = $c->model('DB::Location')->search({ instance => $instance });

    # Get the list of days of the week
    my @days = $c->model('DB::ClosingHour')->search( { instance => $instance,  date => undef } );
    my $days;
    map { $days->{ $_->location() ? $_->location()->id() : q{all} }->{ $_->day() } = $_ } @days;

    # Get the list of specific dates
    my @dates = $c->model('DB::ClosingHour')->search( { instance => $instance, day => undef }, { order_by => { -asc => 'date' } } );

    $c->stash(
        locations => \@locations,
        days => $days,
        dates => \@dates,
    );

}


=head1 AUTHOR

Ian Walls <ian@bywatersolutions.com>

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
