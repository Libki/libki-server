#!/usr/bin/perl

## Sets users' times to opening hours' times.
## If the library closes at 6 pm, the users' time will be up at 6 pm.

## Runs constantly in the background
## i.e. @reboot in cron

#use strict;
use warnings;

use Env;
use Config::JFDI;
use DateTime::Format::MySQL;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki::Schema::DB;

use Data::Dumper;

my $config = Config::JFDI->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
    no_06_warning => 1
);
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

$| = 1;
while ($schema) {
	my @sessions=$schema->resultset('Session')->all;

    if (@sessions){
	       	closing(); 
    }
  sleep 1;
}

sub closing { 
 

	my @days = qw(sunday monday tuesday wednesday thursday friday saturday sunday);
	my @months = qw(01 02 03 04 05 06 07 08 09 10 11 12);
	my @dates = qw(00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31);
	(my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime(time);
	$year += 1900;
	$todays_date = $year."-".$months[$mon]."-".$dates[$mday];
	
	my $current_time = ($hour*60)+$min;

	my $closing_hours_rs = $schema->resultset('Closing_hours');
	while ( my $closing_hours = $closing_hours_rs->next() ) {		

		my $closing_hour = substr $closing_hours->closing_time, 0, 2;
		my $closing_minute = substr $closing_hours->closing_time, -2;
		my $closing_time = ($closing_hour*60)+$closing_minute;
		my $time_difference = $closing_time - $current_time;
	
		if ($closing_hours->day eq $todays_date ) {

			if ($time_difference < $schema->resultset('Setting')->find('DefaultTimeAllowance')->value) {
				my $active_user_rs = $schema->resultset('Session');
				
				while ( my $active_user = $active_user_rs->next() ) {
					my $active_user_minutes = $active_user->user->minutes();
										
					if ( $active_user->user->minutes() > $time_difference ) {
						my $decrease_minutes = $active_user_minutes - $time_difference;
						$active_user->user->decrease_minutes($decrease_minutes);
						$active_user->user->update();
					}
				}
			}
			last;
		}
		elsif ($closing_hours->day eq $days[$wday] ) {
				
			if ($time_difference < $schema->resultset('Setting')->find('DefaultTimeAllowance')->value) {
				
				my $active_user_rs = $schema->resultset('Session');
				
				while ( my $active_user = $active_user_rs->next() ) {
					my $active_user_minutes = $active_user->user->minutes();
					
					if ( $active_user->user->minutes() > $time_difference ) {
						my $decrease_minutes = $active_user_minutes - $time_difference;
						$active_user->user->decrease_minutes($decrease_minutes);
						$active_user->user->update();
					}
				}
			}
			last;
		}

	}
}
