#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/libki/perl5/lib/perl5';

use Env;
use Config::JFDI;
use DateTime::Format::MySQL;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki;
use Libki::Hours;

my $config = Config::JFDI->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
    no_06_warning => 1
);
my $c = Libki->new( { database_file => $config->{'Model::DB'}{args}{database_file} } );

my $lang = 'en';
if ( $c->installed_languages()->{$lang} ) {
    $c->session->{lang} = $lang;
}

my $session_rs     = $c->model('DB::Session');
my $setting_rs     = $c->model('DB::Setting');
my $reservation_rs = $c->model('DB::Reservation');

my $AutomaticTimeExtensionAt           = $setting_rs->find('AutomaticTimeExtensionAt')->value;
my $AutomaticTimeExtensionLength       = $setting_rs->find('AutomaticTimeExtensionLength')->value;
my $AutomaticTimeExtensionUnless       = $setting_rs->find('AutomaticTimeExtensionUnless')->value;
my $AutomaticTimeExtensionUseAllotment = $setting_rs->find('AutomaticTimeExtensionUseAllotment')->value;

## Decrement time for logged in users.
while ( my $session = $session_rs->next() ) {
    my $user = $session->user;
    if ( $user->minutes() > 0 ) {
        ## Decrement the number of minutes but don't commit to db yet
        $user->decrease_minutes(1);

        ## Check to see if user qualifies for an automatic time extension
        if (   $AutomaticTimeExtensionAt
            && $user->minutes() < $AutomaticTimeExtensionAt )
        {
            my $count =
                $AutomaticTimeExtensionUnless eq 'any_reserved'
              ? $reservation_rs->count()
              : $reservation_rs->search( { client_id => $session->client_id } )->count();

            unless ($count) {
                my $minutes_to_add = $AutomaticTimeExtensionLength;

                # If we are nearing closing time, we need to only add minutes up to the cloasing time
                my $minutes_until_closing = Libki::Hours::minutes_until_closing( $c, $session->client->location );

                # If adding this many minutes would go past closing time, we need to reduce the minutes added
                if ( defined($minutes_until_closing)
                    && $minutes_until_closing < $minutes_to_add )
                {
                    # Set the minutes to add so that it will be exactly closing time
                    $minutes_to_add = $minutes_until_closing - $user->minutes;
                }

                # If adding this many minutes would exceed daily allotted, we need to reduce the minutes added
                if ( $AutomaticTimeExtensionUseAllotment eq 'yes' ) {
                    if ($user->minutes_allotment < $minutes_to_add) {
                        # Set the minutes to add so that it will be exactly the remaining daily allotted minutes
                        $minutes_to_add = $user->minutes_allotment;
                    }
                }

                if ( $minutes_to_add > 0 ) {
                    $user->increase_minutes($minutes_to_add);
                    $user->decrease_minutes_allotment($minutes_to_add) if ( $AutomaticTimeExtensionUseAllotment eq 'yes' );
                    $user->create_related(
                        'messages',
                        {
                            content => $c->loc(
                                "Your session time has been automatically extended by [_1] minutes.",
                                $minutes_to_add
                            ),
                        }
                    );
                }
            }
        }

        ## Now it we can store the change
        $user->update();
    }
    else {
        ## If somehow a session exists with
        ## 0 or a negative number of minutes,
        ## we need to clean if out.
        $c->model('DB::Statistic')->create(
            {
                username    => $user->username(),
                client_name => $session->client->name(),
                action      => 'SESSION_DELETED',
                when        => DateTime::Format::MySQL->format_datetime( DateTime->now() ),
            }
        );

        $session->delete();
    }
}

## Delete clients that haven't updated recently
my $post_crash_timeout = $setting_rs->find('PostCrashTimeout')->value;

my $timestamp = DateTime::Format::MySQL->format_datetime( DateTime->now( time_zone => 'local' )
      ->subtract_duration( DateTime::Duration->new( minutes => $post_crash_timeout ) ) );

$c->model('DB::Client')->search( { last_registered => { '<', $timestamp } } )->delete();

## Clear out any expired reservations
$reservation_rs->search(
    {
        'expiration' => { '<', DateTime::Format::MySQL->format_datetime( DateTime->now( time_zone => 'local' ) ) }
    }
)->delete();

## Refill session minutes from allotted minutes for users not logged in to a client
my $default_session_time_allowance = $setting_rs->find('DefaultSessionTimeAllowance')->value;
my $default_guest_session_time_allowance = $setting_rs->find('DefaultGuestSessionTimeAllowance')->value;

my $users_rs = $c->model('DB::User')->search(
    {
        minutes           => { '<' => $default_session_time_allowance },
        minutes_allotment => { '>' => 0 }
    }
);

while ( my $user = $users_rs->next() ) {
    unless ( $user->session() ) {
        my $allowance = $user->is_guest eq 'Yes' ? $default_guest_session_time_allowance : $default_session_time_allowance;

        while ($user->minutes() < $allowance
            && $user->minutes_allotment() > 0 )
        {
            $user->decrease_minutes_allotment(1);
            $user->increase_minutes(1);
        }
        $user->update();
    }
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
