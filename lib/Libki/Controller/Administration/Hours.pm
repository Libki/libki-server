package Libki::Controller::Administration::Hours;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

our @days_of_week =
  qw( Monday Tuesday Wednesday Thursday Friday Saturday Sunday );

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

=head2 update

=cut

sub update_days : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $params = $c->request->params;

    my @locations = $c->model('DB::Location')->search({ instance => $instance });

    my $rs = $c->model('DB::ClosingHour');

    # Default daily hours
    foreach my $day (@days_of_week) {
        my $hour   = $params->{"$day-hour-all"};
        my $minute = $params->{"$day-minute-all"};

        if ( $hour && $minute ) {
            if ( my $d = $rs->single( { instance => $instance, location => undef, day => $day } ) ) {
                $d->update( { location => undef, day => $day, closing_time => "$hour:$minute" } );
            }
            else {
                $rs->create( { instance => $instance, location => undef, day => $day, closing_time => "$hour:$minute" } );
            }
        }
        else {
            if ( my $d = $rs->single( { instance => $instance, location => undef, day => $day } ) ) {
                $d->delete();
            }
        }
    }

    # Daily hours by location
    foreach my $location ( @locations ) {
        my $location_id = $location->id();

        foreach my $day (@days_of_week) {
            my $hour   = $params->{"$day-hour-$location_id"};
            my $minute = $params->{"$day-minute-$location_id"};

            if ( $hour && $minute ) {
                if ( my $d = $rs->single( { instance => $instance, location => $location_id, day => $day } ) ) {
                    $d->update( { location => $location_id, day => $day, closing_time => "$hour:$minute" } );
                }
                else {
                    $rs->create( { instance => $instance, location => $location_id, day => $day, closing_time => "$hour:$minute" } );
                }
            }
            else {
                if ( my $d = $rs->single( { instance => $instance, location => $location_id, day => $day } ) ) {
                    $d->delete();
                }
            }
        }
    }

    $c->response->redirect( $c->uri_for( $self->action_for('index') ) );

}

sub update_dates : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $params = $c->request->params;

    my $rs = $c->model('DB::ClosingHour');

    my $date     = $params->{date};
    my $hour     = $params->{hour};
    my $minute   = $params->{minute};
    my $location = $params->{location} || undef;

    if ( $date && $hour && $minute ) {
        $date = DateTime::Format::DateParse->parse_datetime($date)->ymd();

        my $time = "$hour:$minute";

        $rs->create(
            { 
                instance     => $instance,
                date         => $date,
                closing_time => $time,
                location     => $location,
            }
        );
    }

    $c->response->redirect( $c->uri_for( $self->action_for('index') ) );

}

sub delete_dates : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $params = $c->request->params;

    my $rs = $c->model('DB::ClosingHour');

    if ( $params->{delete} ) {
        my @delete = $params->{delete};
        @delete = @{ $delete[0] } if ref( $delete[0] ) eq 'ARRAY';
        map { $rs->find($_)->delete() } @delete;
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
