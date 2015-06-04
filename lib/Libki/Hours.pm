package Libki::Hours;

use Modern::Perl;

use DateTime::Format::MySQL;
use DateTime;

=item minutes_before_closing

Returns the number of minutes before closing. If we are past the closing time,
the return value will be a negative number of minutes *since* closing.

=cut

sub minutes_until_closing {
    my ($c) = @_;

    my $now = DateTime->now( time_zone => $ENV{TZ} );

    my $today        = $now->ymd();
    my $current_time = $now->hour() . ":" . $now->minute();

    # Look for a specific date first;
    my $closing_hours =
      $c->model('DB::ClosingHour')->single( { date => $today } );

    # Fall back to day of the week
    $closing_hours ||=
      $c->model('DB::ClosingHour')->single( { day => $now->day_name() } );

    return unless $closing_hours;

    my ( $closing_hour, $closing_minute ) =
      split( /:/, $closing_hours->closing_time() );

    my $closing_time = DateTime->new(
        year   => $now->year(),
        month  => $now->month(),
        day    => $now->day(),
        hour   => $closing_hour,
        minute => $closing_minute,
    );

    my $time_diff = $closing_time - $now;
    my $minutes   = $time_diff->in_units('minutes');

    return $minutes;
}

1;
