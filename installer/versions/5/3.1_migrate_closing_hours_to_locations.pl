#!/usr/bin/perl

use Modern::Perl;
use feature 'say';

use Libki;

my $c = Libki->new();

my $instance = $c->instance;

my $client_behavior = $c->setting('ClientBehavior');

my $res_start_time = $c->setting('ReservationOpeningHour') . ":" . $c->setting('ReservationOpeningMinute') . ":00";

my @closing_hours = $c->model('DB::ClosingHour')->search(
    { instance => $instance }
);

my @closing_hr_data = map { {
    close_time => $_->closing_time, 
    location_id => $_->location->id,
    day => $_->day,
    date => $_->date
} } @closing_hours;

my $schema = $c->model('DB')->schema;
my $location_hours;

foreach my $closing_hour (@closing_hr_data) {
    my $reservable = ($client_behavior =~ /RES/) ? 1 : 0;
    my $open_time = $res_start_time ? $res_start_time : "00:00:00";

    my %days = (
        sunday    => 0, monday => 1, tuesday => 2,
        wednesday => 3, thursday => 4, friday => 5,
        saturday  => 6
    );

    say $closing_hour->{'day'} . ": " . $closing_hour->{'close_time'};

    if ($closing_hour->{'date'}) {
        my $location_hours_exception;
        my $location_hours_exception_interval;
        $schema->txn_do(sub {
            $location_hours_exception = $c->model('DB::LocationHoursException')->create({
                location_id => $closing_hour->{'location_id'},
                instance    => $instance,
                service_date => $closing_hour->{'date'}
            });
            $location_hours_exception_interval = $c->model('DB::LocationHoursExceptionInterval')->create({
                exception_id => $location_hours_exception->{'id'},
                instance    => $instance,
                open_time   => $open_time,
                close_time  => $closing_hour->{'close_time'},
                reservable  => $reservable
            });
        });
    } else {
        my $location_hours;
        $schema->txn_do(sub {
            $location_hours = $c->model('DB::LocationHour')->create({
                location_id => $closing_hour->{'location_id'},
                instance    => $instance,
                day_of_week => $days{lc($closing_hour->{'day'})},
                open_time   => $open_time,
                close_time  => $closing_hour->{'close_time'},
                reservable  => $reservable
            }) if $closing_hour->{'location_id'}
        });
    }
}
