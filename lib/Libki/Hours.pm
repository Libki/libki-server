package Libki::Hours;

use Modern::Perl;

use DateTime::Format::MySQL;
use DateTime;

=head2 minutes_until_closing

Returns the number of minutes before closing. If we are past the closing time,
the return value will be a negative number of minutes *since* closing.

=cut

sub minutes_until_closing {
    my ($c, $location_code, $datetime, $instance) = @_;

    $instance ||= $c->instance;

    my $now = defined($datetime) ? $datetime : $c->now();

    my $today        = defined($datetime) ? $datetime->ymd() : $now->ymd();
    my $current_time = defined($datetime) ? ($datetime->hour() . ":" . $datetime->minute()) : ($now->hour() . ":" . $now->minute());

    my $location = $c->model('DB::Location')->single( { instance => $instance, code => $location_code } );

    my $closing_hours;

    # Look for a specific date for a specific location first
    $closing_hours =
      $c->model('DB::ClosingHour')->single( { instance => $instance, location => $location->id(), date => $today } ) if $location;

    # Look for a specific date for a "All locations" second
    $closing_hours ||=
      $c->model('DB::ClosingHour')->single( { instance => $instance, location => undef, date => $today } );

    # Look for a day of the week setting for the given location next
    $closing_hours ||=
      $c->model('DB::ClosingHour')->single( { instance => $instance, location => $location->id(), day => $now->day_name() } ) if $location;

    # Fall back to day of the week for "All locations" last
    $closing_hours ||=
      $c->model('DB::ClosingHour')->single( { instance => $instance, location => undef, day => $now->day_name() } );

    return unless $closing_hours;

    my ( $closing_hour, $closing_minute ) =
      split( /:/, $closing_hours->closing_time() );

    my $closing_time = DateTime->new(
        year      => $now->year(),
        month     => $now->month(),
        day       => $now->day(),
        hour      => $closing_hour,
        minute    => $closing_minute,
        time_zone => $c->tz,
    );

    my $time_diff = $closing_time - $now;
    my $minutes   = $time_diff->in_units('minutes');

    return $minutes;
}

1;
