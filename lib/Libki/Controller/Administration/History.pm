package Libki::Controller::Administration::History;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::History - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
}

sub statistics : Local : Args(0) {
    my ( $self, $c ) = @_;

    my @by_location = $c->model('DB::Statistic')->search(
        { action => 'LOGIN', },
        {
            select => [
                'client_location',
                { 'COUNT' => '*' },
                { 'DAY'   => 'when', '-as' => 'theday' },
                { 'MONTH' => 'when' },
                { 'YEAR'  => 'when' }
            ],
            as       => [ 'location', 'count', 'day', 'month', 'year', ],
            group_by => [
                { 'DAY'   => 'when' },
                { 'MONTH' => 'when' },
                { 'YEAR'  => 'when' },
                'client_location'
            ],
            group_by => [
                { 'DAY'   => 'when' },
                { 'MONTH' => 'when' },
                { 'YEAR'  => 'when' },
                'client_location'
            ],
        }
    );

    my $results;
    my $columns;
    foreach my $b (@by_location) {
        my %columns = $b->get_columns;
        $results->{ $columns{'year'} . '-'
              . $columns{'month'} . '-'
              . $columns{'day'} }->{ $columns{'location'} } = $columns{'count'};
        $columns->{ $columns{'location'} } = 1;
    }
    my @columns = sort keys %$columns;
    $c->stash(
        'by_location'         => $results,
        'by_location_columns' => \@columns,
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
