package Catalyst::Plugin::LibkiSetting;

use Modern::Perl;

use Date::Parse qw( str2time );
use DateTime::Format::DateParse;
use DateTime::Span;
use DateTime;
use List::Util qw( any min max );
use POSIX;
use Try::Tiny;

use Encode qw/ decode encode /;

our $VERSION = 1;

=head2 setting

Returns the setting value for a given setting name and Libki instance.
If the setting does not exist in storage, an empty string will be returned.

=cut

sub setting {
    my ( $c, $params ) = @_;

    my ( $instance, $name );

    if ( ref $params eq 'HASH' ) {
        $instance = $params->{instance};
        $name = $params->{name};
    }
    else {
        $name = $params;
    }

    $instance ||= $c->instance;

    my $setting = $c->model( 'DB::Setting' )->find( { instance => $instance, name => $name } );

    return $setting ? $setting->value : q{};
}

=head2 instance

Returns the current instance name.
The instance name can be set using the environment variable 'LIBKI_INSTANCE'
or via the http header 'libki-instance'
If neither is set, the instance name will be an empty string.

=cut

sub instance {
    my ( $c ) = @_;

    my $header = $c->request->headers->{'libki-instance'} || q{};
    my $env = $ENV{LIBKI_INSTANCE} || q{};

    my $instance = $header || $env || q{};

    return $instance;
}

=head2 instance_config

Locates various parts of the Libki config and returns a unified hashref

=cut

sub instance_config {
    my ($c) = @_;

    my $config = $c->config->{instances}->{ $c->instance } || $c->config;

    my $sip_yaml = $c->setting('SIPConfiguration');
    if ($sip_yaml) {
        try {
            $sip_yaml = encode( 'UTF-8', $sip_yaml );
            $config->{SIP} = YAML::XS::Load($sip_yaml) if $sip_yaml;
        }
        catch {
            warn "Error loading SIP configuration YAML from system setting: $_";
        };
    }

    my $ldap_yaml = $c->setting('LDAPConfiguration');
    if ($ldap_yaml) {
        try {
            $ldap_yaml = encode( 'UTF-8', $ldap_yaml );
            $config->{LDAP} = YAML::XS::Load($ldap_yaml) if $ldap_yaml;
        }
        catch {
            warn "Error loading LDAP configuration YAML from system setting: $_";
        };
    }

    return $config;
}

=head2 now

Returns a DataTime::now object corrected for the current timezone.

=cut

sub now {
    my ( $c ) = @_;

    return DateTime->now( time_zone => $c->tz );
}

=head2 tz

Returns the current timezone

=cut

sub tz {
    return $ENV{LIBKI_TZ};
}

=head2 user_categories

Returns a list of user categories as defined in the system setting UserCategories

=cut

sub user_categories {
    my ($c) = @_;

    my $yaml = $c->setting('UserCategories');

    $yaml = encode( 'UTF-8', $yaml );

    my $categories;
    if ($yaml) {
        try {
            $categories = YAML::XS::Load($yaml);
        }
        catch {
            warn "Error loading UserCategories configuration YAML from system setting: $_";
        };
    }

    return $categories;
}

=head2 add_user_category

Returns a list of user categories as defined in the system setting UserCategories

=cut

sub add_user_category {
    my ( $c, $category ) = @_;

    return unless $category;

    my $categories = $c->user_categories;

    return if grep ( /^$category$/, @$categories );

    my $setting = $c->model('DB::Setting')
        ->find_or_create( { instance => $c->instance, name => 'UserCategories' } );

    push( @$categories, $category );

    my $yaml = YAML::XS::Dump($categories);

    return $setting->update( { value => $yaml } );
}

=head2 get_rules

Returns a perl structure for the rules defined in the setting AdvancedRules

=cut

sub get_rules {
    my ( $c, $instance ) = @_;

    return $c->stash->{AdvancedRules} if defined $c->stash->{AdvancedRules};

    my $yaml = $c->setting( 'AdvancedRules' );
    $yaml = encode( 'UTF-8', $yaml );

    my $data;
    if ($yaml) {
        try {
            $data = YAML::XS::Load($yaml);
        }
        catch {
            warn "Error loading AdvancedRules configuration YAML from system setting: $_";
        };
    }

    $c->stash->{AdvancedRules} = $data || q{};

    return $data;
}

=head2 get_rule

Returns a rule value or undef if no matching rule is found

=cut

sub get_rule {
    my ( $c, $params ) = @_;

    my $instance = $params->{instance};
    my $rule_name = $params->{rule};

    return undef unless $rule_name;

    my $rules = $c->get_rules( $instance );
    return undef unless $rules;

    RULE:
    foreach my $rule ( @$rules ) {
        next if !$rule->{rules}->{$rule_name}; # If this rule doesn't specify this particular 'subrule', just skip it

        foreach my $r ( qw{ user_category client_location client_name client_type } ) {
            my $criteria_is_used = $params->{$r} && 1;
            my $criteria = $rule->{criteria}->{$r};
            my $rule_has_criteria = exists $rule->{criteria}->{$r};
            my $criteria_is_list = ref $criteria eq 'ARRAY';

            my $rule_matches_criteria;
            if ( $criteria_is_list ) {
                $rule_matches_criteria = any { $_ eq $params->{$r} } @$criteria;
            }
            else {
                $rule_matches_criteria = $rule->{criteria}->{$r} eq $params->{$r} if ( $params->{$r} && $rule->{criteria}->{$r} );
            }

            my $skip_rule = $criteria_is_used && $rule_has_criteria && !$rule_matches_criteria;
            next RULE if $skip_rule;
        }

        return $rule->{rules}->{$rule_name};
    }

    return undef;
}

=head2 get_printer_configuration

Returns the printer configuration stored in the database

=cut

sub get_printer_configuration {
    my ( $c, $params ) = @_;

    my $yaml = $c->setting('PrinterConfiguration');
    $yaml = encode( 'UTF-8', $yaml );

    my $config;
    if ($yaml) {
        try {
            $config = YAML::XS::Load( $yaml );
        }
        catch {
            warn "Error loading PrinterConfiguration YAML from system setting: $_";
        };
    }

    return $config;
}

=head2 get_reservation_status

Get the status of the first reservation.

=cut

sub get_reservation_status {
    my ( $c, $client ) = @_;

    my $timeout = $c->setting('ReservationTimeout') || 15;

    my $display = $c->setting('DisplayReservationStatusWithin') || 60;

    my $reservation
        = $c->model('DB::Reservation')
        ->search( { 'client_id' => $client->id }, { order_by => { -asc => 'begin_time' } } )->first
        || undef;

    my $status = undef;
    if ($reservation) {
        my $seconds   = str2time( $reservation->end_time ) - str2time( $reservation->begin_time );
        my $time_left = ( $timeout * 60 ) > $seconds ? $seconds : ( $timeout * 60 );
        my $reserve   = str2time( $reservation->begin_time ) + $time_left - time();
        my $begin     = str2time( $reservation->begin_time ) - time();
        if ( $reserve >= 0 && $reserve <= $time_left ) {
            my $reservation_display_name = $reservation->user->reservation_display_name( $c );
            my $minutes                  = floor( $reserve / 60 );
            my $seconds                  = $reserve % 60;

            $status = $c->loc( '[_1] in [_2] minutes [_3] seconds',
                $reservation_display_name, $minutes, $seconds );
        }
        elsif ( $reserve > $time_left && $begin < $display * 60 ) {
            my $willbereserved = $reserve - $time_left;

            my $reservation_display_name = $reservation->user->reservation_display_name( $c );
            my $minutes                  = floor( $willbereserved / 60 );
            my $seconds                  = ( $willbereserved % 60 );

            $status = $c->loc( '[_1] in [_2] minutes [_3] seconds',
                $reservation_display_name, $minutes, $seconds );
        }
    }
    return $status;
}

=head2 check_login

Check the time and the user, return the available time if possible.

=cut

sub check_login {
    my ( $c, $client, $user ) = @_;
    my $minutes_until_closing = Libki::Hours::minutes_until_closing( { c => $c, location => $client->location } );
    my $timeout = $c->setting( 'ReservationTimeout' ) ? $c->setting( 'ReservationTimeout' ) : 15;
    my %result = ( 'error' => 0, 'detail' => 0, 'minutes' => 0, 'reservation' => undef );
    my $time_to_reservation = 0;
    my $reservation = $c->model( 'DB::Reservation' )->search( { user_id => $user->id(), client_id => $client->id } )->first || undef;
    my $minutes_allotment = $user->minutes( $c, $client );

    # 1. Check if the time is available and get the time_to_reservation
    if ( !$result{'error'} ) {

        $result{'reservation'} = $reservation if ( $reservation );

        my $first_reservation = $c->model( 'DB::Reservation' )->search(
            { client_id => $client->id },
            { order_by => { -asc => 'begin_time' } }
        )->first || undef;

        my $minutes_timeout = $timeout < $minutes_allotment ? $timeout : $minutes_allotment;
        my $begin_time = $c->now;

        ## Calculate the time to the first reservation.
        if ( $first_reservation ) {
            my $reservation_begin_dt = DateTime::Format::MySQL->parse_datetime( $first_reservation->begin_time );
            $reservation_begin_dt->set_time_zone( $c->tz );

            my $minute_before_reservation_begin_dt = $reservation_begin_dt->clone();
            $minute_before_reservation_begin_dt->subtract( minutes => 1 );

            my $reservation_begin_plus_timeout_dt = $reservation_begin_dt->clone();
            $reservation_begin_plus_timeout_dt->add( minutes => $minutes_timeout );

            if (
                $minute_before_reservation_begin_dt <= $c->now # Reservation begins in the past
                    && $reservation_begin_plus_timeout_dt >= $c->now # Reservation will time out in the future
                    && $user->id != $first_reservation->user_id
            ) {
                $result{'error'} = 'RESERVED_FOR_OTHER';
            }
            else {
                my $duration        = $reservation_begin_dt->subtract_datetime( $c->now );
                my $reservation_gap = $c->setting('ReservationGap');

                $time_to_reservation = ( abs( $duration->in_units('minutes') ) - $reservation_gap );

                if ( $time_to_reservation < 1 && $user->id != $first_reservation->user_id ) {
                    $result{'error'} = 'RESERVED_FOR_OTHER';
                }
            }
        }
    }

    # 2. Get the available minutes
    if ( !$result{'error'} ) {
        # Get advanced rule if there is one
        my $allowance = $c->get_rule(
            {
                rule            => $user->is_guest eq 'Yes' ? 'guest_session' : 'session',
                client_location => $client->location,
                client_type     => $client->type,
                client_name     => $client->name,
                client_type     => $client->type,
                user_category   => $user->category,
            }
        );
        $allowance //= $user->is_guest() eq 'Yes'
            ? $c->setting( 'DefaultGuestSessionTimeAllowance' )
            : $c->setting( 'DefaultSessionTimeAllowance' );

        my @array = ( $allowance, $minutes_allotment );
        push( @array, $minutes_until_closing ) if ( $minutes_until_closing );
        push( @array, $time_to_reservation ) if ( $time_to_reservation > 0 );
        my $min = min @array;

        if ( $min > 0 ) {
            $result{'minutes'} = $min;
        }
        else {
            $result{'error'} = 'NO_TIME';
        }
    }

    return %result;
}

=head2 check_reservation

Check if the time is available and return the available time if possible

=cut

sub check_reservation {
    my ( $c, $client, $user, $begin_time ) = @_;

    my $parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M' );
    my $begin_time_dt = $parser->parse_datetime( $begin_time );
    $begin_time_dt->set_time_zone( $c->tz );

    my %result = ( 'error' => 0, 'detail' => 0, 'minutes' => 0, 'allotment' => 0, 'end_time' => $begin_time_dt->clone );

    my @array;
    my $minutes_to_closing = Libki::Hours::minutes_until_closing(
        {
            c        => $c,
            location => $client->location,
            datetime => $begin_time_dt,
        }
    );
    my ( $minutes_left, $minutes ) = ( 0, 0 );

    #1. Check to see if the time has been past
    if ( $begin_time_dt < $c->now ) {
        $result{'error'} = 'INVALID_TIME';
    }

    #2. Check allowance
    if ( !$result{'error'} ) {
        my $allowance = $c->setting( 'DefaultSessionTimeAllowance' );
        if ( $allowance <= 0 ) {
            $result{'error'} = 'INVALID_TIME';
            $result{'detail'} = 'SessionTimeAlowance is 0';
        }
        else {
            push( @array, $allowance );
        }
    }

    #3. Check the closing time
    if ( !$result{'error'} && defined( $minutes_to_closing ) ) {
        if ( $minutes_to_closing > 0 ) {
            push( @array, $minutes_to_closing );
        }
        else {
            $result{'error'} = 'CLOSING_TIME';
        }
    }

    #4. Check the existing reservations
    if ( !$result{'error'} ) {
        my $reservations = $c->model( 'DB::Reservation' )->search(
            { 'client_id' => $client->id },
            {
                order_by => { -asc => 'begin_time' },
            }
        ) || undef;

        while ( my $r = $reservations->next ) {
            my $reservation_begin_time_dt = DateTime::Format::MySQL->parse_datetime( $r->begin_time );
            $reservation_begin_time_dt->set_time_zone( $c->tz );

            my $reservation_end_time_dt = DateTime::Format::MySQL->parse_datetime( $r->end_time );
            $reservation_end_time_dt->set_time_zone( $c->tz );

            my $duration = $reservation_begin_time_dt->subtract_datetime( $begin_time_dt );
            $minutes_left = abs( $duration->in_units( 'minutes' ));

            if ( $reservation_begin_time_dt <= $begin_time_dt && $begin_time_dt < $reservation_end_time_dt ) {
                $result{'error'} = 'INVALID_TIME';
                $result{'detail'} = 'Reserved';
                last;
            }
            elsif ( $minutes_left > 0 ) {
                push( @array, $minutes_left );
                last;
            }
        }
    }

    #5. Check the session
    if ( !$result{'error'} ) {
        my $session = $c->model( 'DB::Session' )->find( { client_id => $client->id } );
        if ( $session ) {
            my $now_plus_session_minutes_dt = $c->now;
            $now_plus_session_minutes_dt->add( minutes => $session->minutes );

            if ( $begin_time_dt < $now_plus_session_minutes_dt ) {
                $result{'error'} = 'INVALID_TIME';
                $result{'detail'} = 'Someone else is using this client';
            }
        }
    }

    #6. Check minutes_allotment
    my $minutes_allotment = $user->minutes( $c, $client );

    if (   !$result{'error'}
        && defined($minutes_allotment)
        && $begin_time_dt->ymd eq $c->now->ymd )
    {
        if ( $minutes_allotment > 0 ) {
            push( @array, $minutes_allotment );
        }
        elsif ( $minutes_allotment <= 0 ) {
            $result{'error'} = 'NO_TIME';
        }
    }

    #7. Check the minimum minutes limit preference
    if ( !$result{'error'} ) {
        my $minimum = $c->setting( 'MinimumReservationMinutes' );
        $minimum = 1 unless $minimum;
        $minutes = min @array;
        if ( $minutes < $minimum ) {
            $result{'error'} = 'MINIMUM_TIME';
        }
        else {
            $result{'minutes'} = $minutes;
            $result{'end_time'} = $result{'end_time'}->add( minutes => $minutes );
        }
    }

    return %result;
}

=head2 get_time_list

 Get the available time list for new reservation

=cut

sub get_time_list {
    my ( $c, $client_id, $date ) = @_;

    my $parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M' );
    my $working_date_dt = $parser->parse_datetime( "$date 0:0" );
    $working_date_dt->set_time_zone( $c->tz );

    # Find existing reservations for the date requested
    my @reservations = $c->model( 'DB::Reservation' )->search(
        {
            -and => [
                instance => $c->instance,
                client_id => $client_id,
                -or       => [
                    \[ 'DATE(begin_time) = ?', $working_date_dt->ymd ],
                    \[ 'DATE(end_time) = ?', $working_date_dt->ymd ],
                ],
            ]
        }
    );

    # Find existing sessions for the client
    my @sessions = $c->model('DB::Session')->search(
        {
            -and => [
                instance  => $c->instance,
                client_id => $client_id,
            ]
        }
    );

    my $client = $c->model( 'DB::Client' )->find( $client_id );

    my ( @mlist, @start, %result );
    my $now_dt = DateTime->now( time_zone => $c->tz );

    my $opening_hour = $c->setting( 'ReservationOpeningHour' ) || 0;
    my $opening_minute = $c->setting( 'ReservationOpeningMinute' ) || 0;
    my $opening_dt = $working_date_dt->clone;
    $opening_dt->set(
        hour   => $opening_hour,
        minute => $opening_minute,
    );

    my $end_dt = $working_date_dt->clone;
    $end_dt->set(
        hour   => 23,
        minute => 59,
    );

    my @hours = ( '00', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12',
        '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23' );
    my @minutes = ( '00', '05', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55' );

    if ( $client ) {
        push( @start, $opening_dt );

        if ( $now_dt->ymd eq $opening_dt->ymd ) {
            push( @start, $now_dt );

            if ( defined( $client ) && defined( $client->session ) ) {
                my $session_end_dt = $now_dt->clone();
                $session_end_dt->add( seconds => $client->session->minutes * 60 );
                push( @start, $session_end_dt );
            }
        }

        my $start_dt = max @start;

        for ( my $i = 0; $i < $start_dt->hour; $i++ ) {
            $hours[$i] = 'hide';
        }

        my $minutes_to_closing = Libki::Hours::minutes_until_closing(
            {
                c        => $c,
                location => $client->location(),
                datetime => $start_dt,
            }
        );

        if ( $minutes_to_closing ) {
            my $close_dt = $start_dt->clone;
            $close_dt->add( minutes => $minutes_to_closing );

            # Hide all the hours after closing
            for ( my $j = $close_dt->hour + 1; $j < 24; $j++ ) {
                $hours[$j] = 'hide';
            }

            $end_dt = $close_dt if $minutes_to_closing > 0;
        }

        for ( my $h = 0; $h < 24; $h++ ) {
            my @minutes_availability = @minutes;

            if ( $hours[$h] ne 'hide' ) {
                for ( my $min = 0; $min < scalar @minutes_availability; $min++ ) {
                    my $time_to_check_dt = $start_dt->clone;
                    $time_to_check_dt->set(
                        hour   => $h,
                        minute => $minutes_availability[$min]
                    );

                    $minutes_availability[$min] = 'hide' if $time_to_check_dt < $now_dt;
                    $minutes_availability[$min] = 'hide' if $time_to_check_dt > $end_dt;

                    foreach my $reservation ( @reservations ) {
                        my $reservation_begin_dt = DateTime::Format::MySQL->parse_datetime( $reservation->begin_time );
                        my $reservation_end_dt = DateTime::Format::MySQL->parse_datetime( $reservation->end_time );

                        $reservation_begin_dt->set_time_zone( $c->tz );
                        $reservation_end_dt->set_time_zone( $c->tz );

                        my $reservation_gap = $c->setting( 'ReservationGap' );
                        $reservation_end_dt->add( minutes => $reservation_gap ) if $reservation_gap;

                        my $reservation_span = DateTime::Span->from_datetimes( start => $reservation_begin_dt, end => $reservation_end_dt );

                        if ( $reservation_span->contains( $time_to_check_dt )
                            || $time_to_check_dt < $start_dt
                            || $time_to_check_dt > $end_dt
                        ) {
                            $minutes_availability[$min] = 'hide';
                            last;
                        }
                    }


                    # Remove hour/minutes selection based on current sessions the same as we do for existing reservations above
                    # Reduces the ability to select an invalid time for a new reservation. GitHub Issue #211
                    foreach my $session ( @sessions ) {
                        my $session_begin_dt = DateTime->now( time_zone => $c->tz );
                        my $session_end_dt = $session_begin_dt + DateTime::Duration->new( minutes => $session->minutes );

                        my $session_gap = $c->setting( 'ReservationGap' );
                        $session_end_dt->add( minutes => $session_gap ) if $session_gap;

                        my $session_span = DateTime::Span->from_datetimes( start => $session_begin_dt, end => $session_end_dt );

                        if ( $session_span->contains( $time_to_check_dt )
                            || $time_to_check_dt < $start_dt
                            || $time_to_check_dt > $end_dt
                        ) {
                            $minutes_availability[$min] = 'hide';
                            last;
                        }
                    }
                }
            }

            push( @mlist, \@minutes_availability );
        }

        $result{'hlist'} = \@hours;
        $result{'mlist'} = \@mlist;
    }
    else {
        $result{'error'} = "Couldn't find the client";
    }

    return %result;
}

=head2 format_dt

  my $formatted = $c->format_dt($DateTime);
  my $formatted = $c->format_dt($iso_string);
  my $formatted = $c->format_dt( { dt => $dt_or_string, include_time => 1 || 0, format => '%Y-%m-%d' } );

 Stringify a DateTime object using the formatted supplied by the setting DateTimeFormat.
 Accepts standard strftime arguments.

=cut

sub format_dt {
    my ( $c, $dt ) = @_;

    my $include_time = 0;
    my $format       = $c->setting('DateDisplayFormat') || '%m/%d/%Y';

    if ( ref $dt eq 'HASH' ) {
        $include_time = $dt->{include_time} if $dt->{include_time};
        $format       = $dt->{format}       if $dt->{format};
        $dt           = $dt->{dt};
    }

    return {} unless $dt;

    if ($include_time) {
        my $TimeDisplayFormat = $c->setting('TimeDisplayFormat') || '12';
        $format .= " %I:%M %p" if $TimeDisplayFormat eq '12';
        $format .= " %H:%M"    if $TimeDisplayFormat eq '24';
    }

    $dt = DateTime::Format::DateParse->parse_datetime($dt)
        if ( $dt && ref $dt ne 'DateTime' );

    return $dt->strftime($format);
}

1;
