#!/usr/bin/perl

use lib '$ENV{HOME}/perl5/lib/perl5';

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Modern::Perl;

use List::Util qw(max min);
use DateTime;
use DateTime::Format::MySQL;

use Libki;

my $c = Libki->new();
my $schema = $c->model('DB::User')->result_source->schema || die("Couldn't Connect to DB");
my $dbh = $schema->storage->dbh;

## Delete any guest accounts
$c->model('DB::User')->search( { is_guest => 'Yes' } )->delete();

## Reset the guest counter
$c->model('DB::Setting')->search( { name => 'CurrentGuestNumber' } )->update( { value => '1' } );

## Reset user minutes
$c->model('DB::User')->update( { minutes_allotment => undef } );

## Set to disabled if a troublemaker
$c->model('DB::User')->search( { is_troublemaker => 'Yes' } )->update( { status => 'disabled' } );

## Clear out statistics that are past the retention length
my @data_retention_days = $c->model('DB::Setting')->search( { name => 'DataRetentionDays' } );
foreach my $drd (@data_retention_days) {
    if ( $drd->value ) {
        my $dt = DateTime->today( time_zone => $ENV{LIBKI_TZ} );
        $dt->subtract( days => $drd->value );
        my $timestamp = DateTime::Format::MySQL->format_datetime($dt);
        $c->model('DB::Statistic')->search( { instance => $drd->instance, 'created_on' => { '<' => $timestamp } } )->delete();
    }
}

## Anonymize statistics that are past the retention length
my @data_anonymization_days = $c->model('DB::Setting')->search( { name => 'DataAnonymizationDays' } );
foreach my $dad (@data_anonymization_days) {
    if ( $dad->value ) {
        my $dt = DateTime->today( time_zone => $ENV{LIBKI_TZ} );
        $dt->subtract( days => $dad->value );
        my $timestamp = DateTime::Format::MySQL->format_datetime($dt);
        my $random_int = int(rand(1000000));
        $c->model('DB::Statistic')->search(
            {
                instance     => $dad->instance,
                'created_on' => { '<' => $timestamp },
                anonymized   => 0,
            }
        )->update(
            {
                username   => \"MD5(CONCAT(username, $random_int))",
                anonymized => 1,
            }
        );
    }
}

## Clear out users that are past the retention length
my @user_retention_days = $c->model('DB::Setting')->search( { name => 'InactiveUserRetentionDays' } );
foreach my $urd (@user_retention_days) {
    if ( $urd->value ) {
        my $dt = DateTime->today( time_zone => $ENV{LIBKI_TZ} );
        $dt->subtract( days => $urd->value );
        my $timestamp = DateTime::Format::MySQL->format_datetime($dt);
        $c->model('DB::User')->search(
            {
                instance             => $urd->instance,
                'created_on'         => { '<' => $timestamp },
                'user_roles.user_id' => undef,
            },
            {
                join => 'user_roles',
            }
        )->delete();
    }
}

## Clear out old print jobs and print files
my @print_retention_days = $c->model('DB::Setting')->search( { name => 'PrintJobRetentionDays' } );
foreach my $prd (@print_retention_days) {
    if ( $prd->value ) {
        my $dt = DateTime->today( time_zone => $ENV{LIBKI_TZ} );
        $dt->subtract( days => $prd->value );
        my $timestamp = DateTime::Format::MySQL->format_datetime($dt);

        $c->model('DB::PrintFile')->search(
            {
                instance             => $prd->instance,
                'created_on'         => { '<' => $timestamp },
            }
        )->delete();

        $c->model('DB::PrintJob')->search(
            {
                instance             => $prd->instance,
                'created_on'         => { '<' => $timestamp },
            }
        )->delete();
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
