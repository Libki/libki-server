#!/usr/bin/perl

use strict;
use warnings;

use Env;
use Config::JFDI;
use DateTime::Format::MySQL;

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

## Decrement time for logged in users.
my $session_rs = $schema->resultset('Session');
while ( my $session = $session_rs->next() ) {
    if ( $session->user->minutes() > 0 ) {
        $session->user->decrease_minutes(1);
        $session->user->update();
    }
}

## Delete clients that haven't updated recently
my $post_crash_timeout =
  $schema->resultset('Setting')->find('PostCrashTimeout')->value;

my $timestamp = DateTime::Format::MySQL->format_datetime(
    DateTime->now( time_zone => 'local' )->subtract_duration(
        DateTime::Duration->new( minutes => $post_crash_timeout )
    )
);

$schema->resultset('Client')
  ->search( { last_registered => { '<', $timestamp } } )->delete();

## Clear out any expired reservations
$schema->resultset('Reservation')->search(
    {
        'expiration' => {
            '<',
            DateTime::Format::MySQL->format_datetime(
                DateTime->now( time_zone => 'local' )
            )
        }
    }
)->delete();

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
