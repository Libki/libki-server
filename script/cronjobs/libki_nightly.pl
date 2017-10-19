#!/usr/bin/perl

use lib '$ENV{HOME}/perl5/lib/perl5';

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

my $c = Libki->new( { database_file => $config->{'Model::DB'}{args}{database_file} } );

my @default_time_allowances = $c->model('DB::Setting')->search( { name => 'DefaultTimeAllowance' } );
my $default_time_allowances = { map { $_->instance => $_->value } @default_time_allowances };

my @default_session_time_allowances = $c->model('DB::Setting')->search( { name => 'DefaultSessionTimeAllowance' } );
my $default_session_time_allowances = { map { $_->instance => $_->value } @default_session_time_allowances };

## Delete any guest accounts
$c->model('DB::User')->search( { is_guest => 'Yes' } )->delete();

## Reset the guest counter
$c->model('DB::Setting')->search( { name => 'CurrentGuestNumber' } )->update( { value => '1' } );

## Reset user minutes, set to disabled if a troublemaker
my $user_rs = $c->model('DB::User');
while ( my $user = $user_rs->next() ) {
    my $instance = $user->instance;

    my $user_minutes = min( $default_time_allowances->{$instance}, $default_session_time_allowances->{$instance} );

    $user->minutes_allotment( $default_time_allowances->{$instance} );
    $user->minutes($user_minutes);
    $user->status('disabled') if ( $user->is_troublemaker eq 'Yes' );
    $user->update();
}

## Clear out statistics that are past the retention length
my @data_retention_days = $c->model('DB::Setting')->search( { name => 'DataRetentionDays' } );
foreach my $drd (@data_retention_days) {
    if ( $drd->value ) {
        my $dt = DateTime->today();
        $dt->subtract( days => $drd->days );
        my $timestamp = DateTime::Format::MySQL->format_datetime($dt);
        $c->model('DB::Statistic')->search( { instance => $drd->instance, 'when' => { '<' => $timestamp } } )->delete();
    }
}

## Clear out expired sessions
## TODO: Should we delete sessions with no expiration periodically?
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
