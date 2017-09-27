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

    my $instance = $c->request->headers->{'libki-instance'};

    my $from = $c->request->params->{'from'};
    my $to   = $c->request->params->{'to'};

    $from ||= DateTime->today()->subtract( months => 1 )->ymd();
    $to ||= DateTime->today()->ymd();

    $from = DateTime::Format::DateParse->parse_datetime($from)->ymd();
    $to   = DateTime::Format::DateParse->parse_datetime($to)->ymd();

    if ( $from gt $to ) {
        ( $from, $to ) = ( $to, $from );
    }

    $from .= " 00:00:00";
    $to .= " 23:59:59";
    my @by_location = $c->model('DB::Statistic')->search(
        {
            instance => $instance,
            when =>
              { '>=' => $from, '<=' => $to, },
            action => 'LOGIN',
        },
        {
            select => [
                'client_location',
                { 'COUNT' => '*' },
                { 'DAY'   => 'when' },
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
        }
    );
    
    my $enc = 'UTF-8';

    my $results;
    my $columns;

    foreach my $b (@by_location) {
        my %columns = $b->get_columns;
        $columns{'location'} = "XXX__UNDEFINED__"
          unless ( defined( $columns{'location'} ) );
        $results->{ $columns{'year'} . '-'
              . sprintf( "%02d", $columns{'month'} ) . '-'
              . sprintf( "%02d", $columns{'day'} ) }->{ $columns{'location'} } =
          $columns{'count'};
        $columns->{ $columns{'location'} } = 1;
    }
    my @columns = sort keys %$columns;
    $c->stash(
        'by_location'         => $results,
        'by_location_columns' => \@columns,
        'from'                => $from,
        'to'                  => $to,
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
