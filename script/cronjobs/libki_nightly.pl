#!/usr/bin/perl

use strict;
use warnings;

use Config::JFDI;
use List::Util qw(max min);

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki::Schema::DB;

my $config = Config::JFDI->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
    no_06_warning => 1
);
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my $default_time_allowance = $schema->resultset('Setting')->find('DefaultTimeAllowance')->value;
my $default_session_time_allowance = $schema->resultset('Setting')->find('DefaultSessionTimeAllowance')->value;

my $user_minutes_allotment = $default_time_allowance;
my $user_minutes = min( $user_minutes_allotment, $default_session_time_allowance );
$user_minutes_allotment -= $user_minutes;

## Delete any guest accounts
$schema->resultset('User')->search({ is_guest => 'Yes' })->delete();

## Reset the guest counter
my $current_guest_number = $schema->resultset('Setting')->find('CurrentGuestNumber');
$current_guest_number->value('1');
$current_guest_number->update();

## Reset user minutes, set to disabled if a troublemaker
my $user_rs = $schema->resultset('User');
while ( my $user = $user_rs->next() ) {
    $user->minutes_allotment( $user_minutes_allotment );
    $user->minutes( $user_minutes );
    $user->status( 'disabled' ) if ( $user->is_troublemaker eq 'Yes' );
    $user->update();
}

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
