#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;
use List::Util qw(min max);
use Sys::Hostname;
use Try::Tiny;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki;
use Libki::Hours;

my ( $opt, $usage ) = describe_options(
    'script/cronjobs/libki.pl %o',
    [ 'verbose|v', "print extra stuff" ],
    [ 'logging|l', "log extra stuff" ],
    [ 'help|h',    "print usage message and exit", { shortcircuit => 1 } ],
);
print($usage->text), exit if $opt->help;

my $c = Libki->new();

my $msg = "Starting Libki cronjob libki.pl";
say $msg             if $opt->verbose;
$c->log->debug($msg) if $opt->logging;
$c->model('DB::Log')->create(
    {
        instance   => $c->instance,
        created_on => DateTime->now( time_zone => $ENV{LIBKI_TZ} ),
        level      => "INFO",
        message    => $msg,
        hostname   => hostname(),
        pid        => $$,
    }
);

my $lang = 'en';
if ( $c->installed_languages()->{$lang} ) {
    $c->session->{lang} = $lang;
}

my $setting_rs     = $c->model('DB::Setting');
my $reservation_rs = $c->model('DB::Reservation');
my $message_rs     = $c->model('DB::Message');

my $schema = $c->schema;
my $dbh    = $schema->storage->dbh;

## Gather sessions to delete, delete them, then log the deletions
my $when = DateTime::Format::MySQL->format_datetime( DateTime->now( time_zone => $ENV{LIBKI_TZ} ) );

# strings depending on TimeAllowanceByLocation for queries using minutes allotments
my $timeAllowanceByLocation = $c->setting('TimeAllowanceByLocation');
my $location = ($timeAllowanceByLocation) ? "clients.location" : "''";
my $join_clients_sessions     = ($timeAllowanceByLocation) ? "LEFT JOIN clients ON ( clients.instance = sessions.instance AND clients.id = sessions.client_id )" : "";
my $join_clients_reservations = ($timeAllowanceByLocation) ? "LEFT JOIN clients ON ( clients.instance = reservations.instance AND clients.id = reservations.client_id )" : "";

# Gather the sessions to delete for statistical purposes
my $sessions_to_delete = $dbh->selectall_arrayref(
    qq{
        SELECT * FROM sessions
        LEFT JOIN users ON ( users.instance = sessions.instance AND users.id = sessions.user_id )
        LEFT JOIN clients ON ( clients.instance = sessions.instance AND clients.id = sessions.client_id )
        LEFT JOIN allotments ON ( allotments.instance = sessions.instance AND allotments.user_id = sessions.user_id AND allotments.location = $location )
        WHERE sessions.minutes <= 0 OR allotments.minutes <= 0
    },
    { Slice => {} }
);

# Delete sessions with a single query for efficiency
$dbh->do(qq{
    DELETE sessions
    FROM sessions
    $join_clients_sessions
    LEFT JOIN allotments ON ( allotments.instance = sessions.instance AND allotments.user_id = sessions.user_id AND allotments.location = $location )
    WHERE sessions.minutes <= 0 OR allotments.minutes <= 0
});

foreach my $s (@$sessions_to_delete) {
    $c->model('DB::Statistic')->create(
        {
            instance    => $s->{instance},
            username    => $s->{username},
            client_name => $s->{name},
            action      => 'SESSION_DELETED',
            created_on  => $when,
            session_id  => $s->{session_id},
        }
    );
}

## Decrement minutes for logged in users
$dbh->do(qq{
    UPDATE sessions
    $join_clients_sessions
    LEFT JOIN allotments ON ( allotments.instance = sessions.instance AND allotments.user_id = sessions.user_id AND allotments.location = $location )
    SET
        sessions.minutes = sessions.minutes - 1,
        allotments.minutes = allotments.minutes - 1
});

## Decrement minutes allotments for reservation begins but not logged in users
$dbh->do(qq{
    UPDATE allotments
    INNER JOIN reservations ON (
        reservations.begin_time < now()
      AND
        reservations.end_time > now()
      AND
        reservations.user_id = allotments.user_id
      AND
        allotments.minutes > 0
    )
    $join_clients_reservations
    SET
        allotments.minutes = allotments.minutes -1
    WHERE
        allotments.location = $location
});

## Handle automatic time extensions
my $sessions = $dbh->selectall_arrayref(
    qq{
        SELECT users.*, 
               sessions.*, 
               clients.location,
               allotments.minutes                       AS 'minutes_allotment',
               AutomaticTimeExtensionAt.value           AS 'AutomaticTimeExtensionAt', 
               AutomaticTimeExtensionLength.value       AS 'AutomaticTimeExtensionLength', 
               AutomaticTimeExtensionUnless.value       AS 'AutomaticTimeExtensionUnless', 
               AutomaticTimeExtensionUseAllotment.value AS 'AutomaticTimeExtensionUseAllotment', 
               Count(any_reserved.instance)             AS 'AnyReservedCount', 
               Count(this_reserved.client_id)           AS 'ThisReservedCount' 
        FROM   sessions 
        LEFT JOIN clients
              ON ( clients.instance = sessions.instance 
                   AND clients.id = sessions.client_id ) 
        LEFT JOIN users 
              ON ( users.instance = sessions.instance 
                   AND users.id = sessions.user_id ) 
        LEFT JOIN allotments
              ON ( allotments.instance = sessions.instance
                   AND allotments.user_id = sessions.user_id
                   AND allotments.location = $location )
        LEFT JOIN settings AutomaticTimeExtensionAt 
              ON ( users.instance = AutomaticTimeExtensionAt.instance 
                   AND AutomaticTimeExtensionAt.name = 'AutomaticTimeExtensionAt' ) 
        LEFT JOIN settings AutomaticTimeExtensionLength 
              ON ( users.instance = AutomaticTimeExtensionLength.instance 
                   AND AutomaticTimeExtensionLength.name = 'AutomaticTimeExtensionLength' ) 
        LEFT JOIN settings AutomaticTimeExtensionUnless 
              ON ( users.instance = AutomaticTimeExtensionUnless.instance 
                   AND AutomaticTimeExtensionUnless.name = 'AutomaticTimeExtensionUnless' ) 
        LEFT JOIN settings AutomaticTimeExtensionUseAllotment 
              ON ( users.instance = AutomaticTimeExtensionUseAllotment.instance 
                   AND AutomaticTimeExtensionUseAllotment.name = 'AutomaticTimeExtensionUseAllotment' ) 
        LEFT JOIN reservations any_reserved 
               ON ( users.instance = any_reserved.instance ) 
        LEFT JOIN reservations this_reserved 
               ON ( users.instance = this_reserved.instance 
                    AND this_reserved.client_id = sessions.client_id ) 
        WHERE  sessions.minutes < AutomaticTimeExtensionAt.value 
               AND AutomaticTimeExtensionLength.value > 0
               AND sessions.status = 'active' 
        GROUP  BY users.id, 
                  any_reserved.instance, 
                  this_reserved.client_id 
    },
    { Slice => {} }
);

my $update_user_sth = $dbh->prepare(qq{
    UPDATE sessions
    $join_clients_sessions
    LEFT JOIN allotments ON ( allotments.instance = sessions.instance AND allotments.user_id = sessions.user_id AND allotments.location = $location )
    SET sessions.minutes = sessions.minutes + ?, allotments.minutes = allotments.minutes + ? WHERE allotments.user_id = ?});

my $all_minutes_until_closing = {};
foreach my $s ( @$sessions ) {

    # TODO Integrate this into the query
    next if $s->{AutomaticTimeExtensionUnless} eq 'this_reserved' && $s->{ThisReservedCount} > 0;
    next if $s->{AutomaticTimeExtensionUnless} eq 'any_reserved'  && $s->{AnyReservedCount} > 0;

    my $minutes_to_add_to_session = $s->{AutomaticTimeExtensionLength};

    # If we are nearing closing time, we need to only add minutes up to the cloasing time
    # TODO We could possibly integrate this into the main query, or at least speed it up with raw SQL
    $all_minutes_until_closing->{ $s->{instance} }->{ $s->{location} }
        ||= Libki::Hours::minutes_until_closing(
            {
                c        => $c,
                location => $s->{location},
                instance => $s->{instance}
            }
        );

    my $minutes_until_closing = $all_minutes_until_closing->{ $s->{instance} }->{ $s->{location} };

    # If adding this many minutes would go past closing time, we need to reduce the minutes added
    if ( defined($minutes_until_closing)
        && $minutes_until_closing < $minutes_to_add_to_session )
    {
        # Set the minutes to add so that it will be exactly closing time
        $minutes_to_add_to_session = $minutes_until_closing - $s->{minutes};
    }

    # If adding this many minutes would exceed daily allotted, we need to reduce the minutes added
    if ( $s->{AutomaticTimeExtensionUseAllotment} eq 'yes' ) {
        if ( $s->{minutes_allotment} < $s->{minutes_to_add} ) {

            # Set the minutes to add so that it will be exactly the remaining daily allotted minutes
            $minutes_to_add_to_session = $s->{minutes_allotment};
        }
    }

    $message_rs->create(
        {
            instance => $s->{instance},
            user_id  => $s->{id},
            content  => $c->loc(
                "Your session time has been automatically extended by $minutes_to_add_to_session minutes.",
                "Your session time has been automatically extended by $minutes_to_add_to_session minutes.",
                $minutes_to_add_to_session
            ),
        }
    );

    ## Now we can store the changes
    my $minutes_to_add_to_daily_allotment = $s->{AutomaticTimeExtensionUseAllotment} eq 'yes' ? 0 : $minutes_to_add_to_session;
    $update_user_sth->execute( $minutes_to_add_to_session, $minutes_to_add_to_daily_allotment, $s->{id} );
}

## Delete clients that haven't updated recently
my @post_crash_timeouts = $setting_rs->search( { name => 'PostCrashTimeout' } );
foreach my $pct (@post_crash_timeouts) {
    my $timestamp = DateTime::Format::MySQL->format_datetime(
        DateTime->now( time_zone => $ENV{LIBKI_TZ} )->subtract_duration(
            DateTime::Duration->new( minutes => $pct->value )
        )
    );

    $c->model('DB::Client')
      ->search( { instance => $pct->instance, last_registered => { '<', $timestamp }, status => 'online' } )
      ->update( { status => 'offline' } );
}

## Clear out any expired reservations
#FIXME We need to deal with timezones at some point
my $timeout =  $setting_rs->find( { name => 'ReservationTimeout'} );
$reservation_rs->search([
    {
        'begin_time' => {
            '<',
            DateTime::Format::MySQL->format_datetime(
                DateTime->now( time_zone => $ENV{LIBKI_TZ} )->subtract_duration( DateTime::Duration->new(minutes => $timeout->value()) )
            )
        }
    },
    {
        'end_time' => {
            '<',
            DateTime::Format::MySQL->format_datetime(
                DateTime->now( time_zone => $ENV{LIBKI_TZ} )
            )
       }
    }
])->delete();

## Renew time for users that's reached zero if AutomaticTimeExtensionRenewal is set to 1
my @instances = $dbh->selectrow_array("SELECT DISTINCT(instance) FROM users");
foreach my $instance ( @instances ) {
    my $automaticTimeExtensionLength = $dbh->selectrow_array("SELECT value FROM settings WHERE name = 'AutomaticTimeExtensionLength'");
    my $automaticTimeExtensionRenewal = $dbh->selectrow_array("SELECT value FROM settings WHERE name = 'AutomaticTimeExtensionRenewal'");

    if ($automaticTimeExtensionRenewal eq 1 && $automaticTimeExtensionLength ne undef) {
        $dbh->do(q{
            UPDATE allotments SET minutes = ? WHERE instance = ? AND minutes < 1
        }, undef, $instance, $automaticTimeExtensionLength);
    }
}

## automatic power on
my $wake_hour = $c->setting('ClientWakeHour');
if ( $wake_hour || DateTime->now( time_zone => $ENV{LIBKI_TZ} )->hour == $wake_hour ) {
    my $wake_minutes = $c->setting('ClientWakeMinute') || 0;
    if ( DateTime->now( time_zone => $ENV{LIBKI_TZ} )->minute == $wake_minutes ) {
        my $wol_mode = $c->setting('WOLMode') || "server";
        if ( $wol_mode eq "server" ) {
            Libki::Clients::wakeonlan($c);
        } elsif ( $wol_mode eq "client" ) {
            my $clients = $c->model('DB::Client')->search({ instance => $c->instance });
            while ( my $client = $clients->next() ) {
                if ($client->status eq 'online') {
                    $client->update( { status => 'wakeup' } );
                }
            }
        }
    }
}

## automatic power off
my $minutes_to_shutdown = $c->setting('ClientShutdownDelay');
if (length($minutes_to_shutdown)) {
    my $status  = $c->setting('ClientShutdownAction') || 'shutdown';
    my $clients = $c->model('DB::Client')->search({ instance => $c->instance });
    while ( my $client = $clients->next() ) {
        if ( $client->status eq 'online' ) {
            my $minutes_until_closing = Libki::Hours::minutes_until_closing({
                c        => $c,
                location => $client->location,
                instance => $client->instance
            });

            if ( defined $minutes_until_closing && ($minutes_until_closing + $minutes_to_shutdown) == 0 ) {
                $client->update({ status => $status });
            }
        }
    }
}

## Reset Queued print jobs that have been waiting X minutes to Pending so they can be tried again
my $clone_query = q{
INSERT INTO print_jobs
            (instance,
             id,
             type,
             status,
             copies,
             data,
             printer,
             user_id,
             print_file_id,
             created_on,
             updated_on,
             released_on,
             queued_on,
             queued_to)
SELECT instance,
       NULL,
       type,
       status,
       copies,
       data,
       printer,
       user_id,
       print_file_id,
       NOW(),
       NOW(),
       released_on,
       NULL,
       NULL
FROM   print_jobs
WHERE  instance = ?
       AND queued_on < ?
       AND status = 'Queued'  
};

my $expire_query = q{
UPDATE print_jobs
   SET status = 'Expired'
 WHERE instance = ?
   AND queued_on < ?
   AND status = 'Pending'
};

my $clone_sth = $dbh->prepare( $clone_query );
my $expire_sth = $dbh->prepare( $expire_query );

my @print_job_timeouts = $setting_rs->search( { name => 'QueuedPrintJobsTimeout' } );


$dbh->{AutoCommit} = 0; # enable transactions
$dbh->{RaiseError} = 1; # die if a query has problems

try {
    foreach my $pjt (@print_job_timeouts) {
        next unless $pjt->value;

        my $timestamp
            = DateTime::Format::MySQL->format_datetime(
            DateTime->now( time_zone => $ENV{LIBKI_TZ} )
                ->subtract_duration( DateTime::Duration->new( minutes => $pjt->value ) ) );
        $clone_sth->execute( $pjt->instance, $timestamp );
        $expire_sth->execute( $pjt->instance, $timestamp );
    }

    $dbh->commit();
}
catch {
    warn "Handle expired queued print jobs failed: $_";
    try {
        $dbh->rollback();
    } catch {
        warn "Handle expired queued print jobs failed rollback failed!: $_";
    }
};

$dbh->{AutoCommit} = 1;
$dbh->{RaiseError} = 0;
## END Reset Queued print jobs that have been waiting X minutes to Pending so they can be tried again

$msg = "Finished running Libki cronjob libki.pl";
say $msg             if $opt->verbose;
$c->log->debug($msg) if $opt->logging;
$c->model('DB::Log')->create(
    {
        instance   => $c->instance,
        created_on => DateTime->now( time_zone => $ENV{LIBKI_TZ} ),
        level      => "INFO",
        message    => $msg,
        hostname   => hostname(),
        pid        => $$,
    }
);

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
