#!/usr/bin/perl

use Modern::Perl;

use Config::ZOMG;
use List::Util qw(max min);
use DateTime;
use DateTime::Format::MySQL;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki;

my $config = Config::ZOMG->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
);
my $config_hash  = $config->load();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $c = Libki->new(
    { database_file => $config->{'Model::DB'}{args}{database_file} } );

my $default_time_allowance = $c->model('DB::Setting')->find('DefaultTimeAllowance')->value;
my $default_session_time_allowance = $c->model('DB::Setting')->find('DefaultSessionTimeAllowance')->value;

my $user_minutes_allotment = $default_time_allowance;
my $user_minutes = min( $user_minutes_allotment, $default_session_time_allowance );
$user_minutes_allotment -= $user_minutes;

## Delete any guest accounts
$c->model('DB::User')->search({ is_guest => 'Yes' })->delete();

## Reset the guest counter
my $current_guest_number = $c->model('DB::Setting')->find('CurrentGuestNumber');
$current_guest_number->value('1');
$current_guest_number->update();

## Reset user minutes, set to disabled if a troublemaker
my $user_rs = $c->model('DB::User');
while ( my $user = $user_rs->next() ) {
    $user->minutes_allotment( $user_minutes_allotment );
    $user->minutes( $user_minutes );
    $user->status( 'disabled' ) if ( $user->is_troublemaker eq 'Yes' );
    $user->update();
}

## Clear out statistics that are past the retention length
my $data_retention_days = $c->model('DB::Setting')->find('DataRetentionDays')->value;
if ( $data_retention_days ) {
    my $dt = DateTime->today();
    $dt->subtract( days => $data_retention_days );
    my $timestamp = DateTime::Format::MySQL->format_datetime($dt);
    $c->model('DB::Statistic')->search( { 'when' => { '<' => $timestamp }  } )->delete();
}

## Clear out expired sessions
$c->delete_expired_sessions();

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info> 

=cut

=head1 LICENSE
This file is part of Libki.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.   

=cut
