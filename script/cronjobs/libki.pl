#!/usr/bin/perl

use Modern::Perl;

use List::Util qw(min max);

use Libki;
use Libki::Hours;

my $c = Libki->new();

my $lang = 'en';
if ( $c->installed_languages()->{$lang} ) {
    $c->session->{lang} = $lang;
}

my $setting_rs     = $c->model('DB::Setting');
my $reservation_rs = $c->model('DB::Reservation');
my $message_rs     = $c->model('DB::Message');

my $schema = $c->model('DB::User')->result_source->schema || die("Couldn't Connect to DB");
my $dbh = $schema->storage->dbh;

## Gather sessions to delete, delete them, then log the deletions
my $when = DateTime::Format::MySQL->format_datetime( DateTime->now() );

my $sessions_to_delete = $dbh->selectall_arrayref(
    q{
        SELECT * FROM sessions
        LEFT JOIN users ON ( users.instance = sessions.instance AND users.id = sessions.user_id )
        LEFT JOIN clients ON ( clients.instance = sessions.instance AND clients.id = sessions.client_id )
        WHERE users.minutes <= 0
    },
    { Slice => {} }
);

$dbh->do(q{DELETE sessions FROM sessions LEFT JOIN users ON ( users.instance = sessions.instance AND users.id = sessions.user_id ) WHERE users.minutes <= 0});

foreach my $s (@$sessions_to_delete) {
    $c->model('DB::Statistic')->create(
        {
            instance    => $s->{instance},
            username    => $s->{username},
            client_name => $s->{name},
            action      => 'SESSION_DELETED',
            when        => $when,
        }
    );
}

## Decrement minutes for logged in users
$dbh->do(q{UPDATE sessions LEFT JOIN users ON ( users.instance = sessions.instance AND users.id = sessions.user_id ) SET users.minutes = users.minutes - 1});

## Handle automatic time extensions
my $sessions = $dbh->selectall_arrayref(
    q{
        SELECT users.*, 
               sessions.*, 
               AutomaticTimeExtensionAt.value           AS 'AutomaticTimeExtensionAt', 
               AutomaticTimeExtensionLength.value       AS 'AutomaticTimeExtensionLength', 
               AutomaticTimeExtensionUnless.value       AS 'AutomaticTimeExtensionUnless', 
               AutomaticTimeExtensionUseAllotment.value AS 'AutomaticTimeExtensionUseAllotment', 
               Count(any_reserved.instance)             AS 'AnyReservedCount', 
               Count(this_reserved.client_id)           AS 'ThisReservedCount' 
        FROM   sessions 
        LEFT JOIN users 
              ON ( users.instance = sessions.instance 
                   AND users.id = sessions.user_id ) 
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
        WHERE  users.minutes < AutomaticTimeExtensionAt.value 
               AND AutomaticTimeExtensionLength.value > 0
               AND sessions.status = 'active' 
        GROUP  BY users.id, 
                  any_reserved.instance, 
                  this_reserved.client_id 
    },
    { Slice => {} }
);

my $update_user_sth = $dbh->prepare(q{UPDATE users SET minutes = minutes + ?, minutes_allotment = minutes_allotment - ? WHERE id = ?});

my $all_minutes_until_closing = {};
foreach my $s ( @$sessions ) {

    # TODO Integrate this into the query
    next if $s->{AutomaticTimeExtensionUnless} eq 'this_reserved' && $s->{ThisReservedCount} > 0;
    next if $s->{AutomaticTimeExtensionUnless} eq 'any_reserved'  && $s->{AnyReservedCount} > 0;

    my $minutes_to_add = $s->{AutomaticTimeExtensionLength};

    # If we are nearing closing time, we need to only add minutes up to the cloasing time
    # TODO We could possibly integrate this into the main query, or at least speed it up with raw SQL
    $all_minutes_until_closing->{ $s->{instance} }->{ $s->{location} }
        ||= Libki::Hours::minutes_until_closing( $c, $s->{location}, $s->{instance} );

    my $minutes_until_closing = $all_minutes_until_closing->{ $s->{instance} }->{ $s->{location} };

    # If adding this many minutes would go past closing time, we need to reduce the minutes added
    if ( defined($minutes_until_closing)
        && $minutes_until_closing < $minutes_to_add )
    {
        # Set the minutes to add so that it will be exactly closing time
        $minutes_to_add = $minutes_until_closing - $s->{minutes};
    }

    # If adding this many minutes would exceed daily allotted, we need to reduce the minutes added
    if ( $s->{AutomaticTimeExtensionUseAllotment} eq 'yes' ) {
        if ( $s->{minutes_allotment} < $s->{minutes_to_add} ) {

            # Set the minutes to add so that it will be exactly the remaining daily allotted minutes
            $minutes_to_add = $s->{minutes_allotment};
        }
    }

        $message_rs->create(
            {
                instance => $s->{instance},
                user_id  => $s->{id},
                content  => $c->loc(
                    "Your session time has been automatically extended by $minutes_to_add minutes.",
                    "Your session time has been automatically extended by $minutes_to_add minutes.",
                    $minutes_to_add
                ),
            }
        );

    ## Now we can store the changes
    $update_user_sth->execute( $minutes_to_add, $s->{AutomaticTimeExtensionUseAllotment} eq 'yes' ? $minutes_to_add : 0, $s->{id} );
}

## Delete clients that haven't updated recently
my @post_crash_timeouts = $setting_rs->search( { name => 'PostCrashTimeout' } );

foreach my $pct (@post_crash_timeouts) {
    my $timestamp = DateTime::Format::MySQL->format_datetime(
        DateTime->now( time_zone => 'local' )->subtract_duration(
            DateTime::Duration->new( minutes => $pct->value )
        )
    );

    $c->model('DB::Client')
      ->search( { instance => $pct->instance, last_registered => { '<', $timestamp } } )
      ->delete();
}

## Clear out any expired reservations
#FIXME We need to deal with timezones at some point
$reservation_rs->search(
    {
        'expiration' => {
            '<',
            DateTime::Format::MySQL->format_datetime(
                DateTime->now( time_zone => 'local' )
            )
        }
    }
)->delete();

## Refill session minutes from allotted minutes for users not logged in to a client
my @default_session_time_allowances = $setting_rs->search( { name => 'DefaultSessionTimeAllowance' } );
my $default_session_time_allowances = { map { $_->instance => $_->value } @default_session_time_allowances };

my @default_guest_session_time_allowances = $setting_rs->search( { name => 'DefaultGuestSessionTimeAllowance' } );
my $default_guest_session_time_allowances = { map { $_->instance => $_->value } @default_guest_session_time_allowances };

my @users;
foreach my $dsta (@default_session_time_allowances) {
    my @these_users = $c->model('DB::User')->search(
        {
            minutes           => { '<' => $dsta->value },
            minutes_allotment => { '>' => 0 }
        },
        { prefetch => 'session' }
    );

    push( @users, @these_users );
}

foreach my $user (@users) {
    next if $user->session(); #TODO Move to query

    my $allowance =
        $user->is_guest eq 'Yes'
      ? $default_guest_session_time_allowances->{ $user->instance }
      : $default_session_time_allowances->{ $user->instance };

    my $max_minutes = $allowance - $user->minutes;
    my $minutes = min( $user->minutes_allotment, $max_minutes );
    
    $user->decrease_minutes_allotment($minutes);
    $user->increase_minutes($minutes);

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
