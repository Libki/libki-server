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

=head2 logs

=cut

sub logs : Local : Args(0) {
    my ( $self, $c ) = @_;
}

=head2 statistics

Controller to format history as a table with totals.

=cut

sub statistics : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $operation = $c->request->params->{'operation'} || 'location';
    my $from = $c->request->params->{'from'};
    my $to   = $c->request->params->{'to'};

    $from ||= DateTime->today( time_zone => $c->tz )->subtract( months => 1 )->ymd();
    $to ||= DateTime->today( time_zone => $c->tz )->ymd();

    my $from_dt = DateTime::Format::DateParse->parse_datetime($from);
    my $to_dt   = DateTime::Format::DateParse->parse_datetime($to);

    $from = $from_dt->ymd();
    $to   = $to_dt->ymd();

    if ( $from gt $to ) {
        ( $from, $to ) = ( $to, $from );
    }

    $from .= " 00:00:00";
    $to .= " 23:59:59";
    my @by_location = $c->model('DB::Statistic')->search(
        {
            instance => $instance,
            created_on =>
              { '>=' => $from, '<=' => $to, },
            action => 'LOGIN',
        },
        {
            select => [
                'client_location',
                { 'COUNT' => '*' },
                { 'DAY'   => 'created_on' },
                { 'MONTH' => 'created_on' },
                { 'YEAR'  => 'created_on' }
            ],
            as       => [ 'location', 'count', 'day', 'month', 'year', ],
            group_by => [
                { 'DAY'   => 'created_on' },
                { 'MONTH' => 'created_on' },
                { 'YEAR'  => 'created_on' },
                'client_location'
            ],
        }
    );
    
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

    #statistics of client
    my @client_result;
    my @by_client = $c->model('DB::Statistic')->search(
        {
            instance => $instance,
            created_on =>
              { '>=' => $from, '<=' => $to, },
            action => 'LOGIN',
        },
        {
            select => [
                'client_name',
                { 'COUNT' => '*' },
                'client_location',
            ],
            as       => [ 'name', 'count', 'location', ],
            group_by => [
                'client_name'
            ],
        }
    );

    foreach my $client (@by_client) {
        push ( @client_result, $client->{'_column_data'});
    }

    #statistics of reservation
    my $reservation_from = $c->request->params->{'reservation_from'};
    my $reservation_to   = $c->request->params->{'reservation_to'};

    $reservation_from ||= DateTime->today( time_zone => $c->tz )->ymd();
    $reservation_to ||= DateTime->today( time_zone => $c->tz )->add( months => 1 )->ymd();

    my $reservation_from_dt = DateTime::Format::DateParse->parse_datetime($reservation_from);
    my $reservation_to_dt   = DateTime::Format::DateParse->parse_datetime($reservation_to);

    $reservation_from = $reservation_from_dt->ymd();
    $reservation_to   = $reservation_to_dt->ymd();

    if ( $reservation_from gt $reservation_to ) {
        ( $reservation_from, $reservation_to ) = ( $reservation_to, $reservation_from );
    }

    $reservation_from .= " 00:00:00";
    $reservation_to .= " 23:59:59";
    my @by_reservation = $c->model('DB::Reservation')->search(
        {
            instance => $instance,
            begin_time =>
              { 'BETWEEN' => [ $reservation_from, $reservation_to ], },
        },
        {
            select => [
                'client_id',
                { 'COUNT' => '*' },
            ],
            as       => [ 'client_id', 'count', ],
            group_by => [
                'client_id'
            ],
        }
    );

    my @reservation_result;
    foreach my $r (@by_reservation) {
        my %reservation;
        my $client_id = $r->{'_column_data'}->{'client_id'};
        my $client = $c->model('DB::Client')->find($client_id);
        $reservation{'count'} = $r->{'_column_data'}->{'count'};
        $reservation{'client'} = $client->name;
        $reservation{'location'} = $client->location;
        push ( @reservation_result, \%reservation );
    }
    $c->stash(
        'by_location'         => $results,
        'by_location_columns' => \@columns,
        'from'                => $from_dt,
        'to'                  => $to_dt,
        'by_client'           => \@client_result,
        'by_reservation'      => \@reservation_result,
        'reservation_from'    => $reservation_from_dt,
        'reservation_to'      => $reservation_to_dt,
        'operation'           => $operation,
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
