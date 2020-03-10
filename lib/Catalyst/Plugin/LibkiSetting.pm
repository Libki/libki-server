package Catalyst::Plugin::LibkiSetting;

use Modern::Perl;
use List::Util qw(any min);
use Date::Parse;
use POSIX;

use Encode qw/decode encode/;

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
        $name     = $params->{name};
    } else {
        $name = $params;
    }

    $instance ||= $c->instance;

    my $setting = $c->model('DB::Setting')->find( { instance => $instance, name => $name } );

    return $setting ? $setting->value : q{};
}

=head2 instance

Returns the current instance name.
The instance name can be set using the environment variable 'LIBKI_INSTANCE'
or via the http header 'libki-instance'
If neither is set, the instance name will be an empty string.

=cut

sub instance {
    my ($c) = @_;

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

    unless ( $config->{SIP} ) {
        my $yaml = $c->setting('SIPConfiguration');
        $yaml = encode('UTF-8',$yaml);
        $config->{SIP} = YAML::XS::Load($yaml) if $yaml;
    }

    unless ( $config->{LDAP} ) {
        my $yaml = $c->setting('LDAPConfiguration');
        $yaml = encode('UTF-8',$yaml);
        $config->{LDAP} = YAML::XS::Load($yaml) if $yaml;
    }

    return $config;
}

=head2 now

Returns a DataTime::now object corrected for the current timezone.

=cut

sub now {
    my ($c) = @_;

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
    my ( $c ) = @_;

    my $yaml = $c->setting('UserCategories');

    $yaml = encode('UTF-8',$yaml);

    my $categories = YAML::XS::Load($yaml) if $yaml;

    return $categories;
}


=head2 add_user_category

Returns a list of user categories as defined in the system setting UserCategories

=cut

sub add_user_category {
    my ( $c, $category ) = @_;

    return unless $category;

    my $categories = $c->user_categories;

    return if grep( /^$category$/, @$categories );

    my $setting = $c->model('DB::Setting')->find(
        {
            instance => $c->instance,
            name     => 'UserCategories',
        }
    );

    push( @$categories, $category );

    my $yaml = YAML::XS::Dump( $categories );

    return $setting->update( { value => $yaml } );
}

=head2 get_rules

Returns a perl structure for the rules defined in the setting AdvancedRules

=cut

sub get_rules {
    my ( $c, $instance ) = @_;

    return $c->stash->{AdvancedRules} if defined $c->stash->{AdvancedRules};

    my $yaml = $c->setting( { instance => $instance, name => 'AdvancedRules' } );
    $yaml = encode('UTF-8',$yaml);

    my $data = YAML::XS::Load($yaml) if $yaml;

    $c->stash->{AdvancedRules} = $data || q{};

    return $data;
}

=head2 get_rule

Returns a rule value or undef if no matching rule is found

=cut

sub get_rule {
    my ( $c, $params ) = @_;

    my $instance  = $params->{instance};
    my $rule_name = $params->{rule};

    return undef unless $rule_name;

    my $rules = $c->get_rules($instance);
    return undef unless $rules;

    RULE: foreach my $rule (@$rules) {
        next if !$rule->{rules}->{$rule_name}; # If this rule doesn't specify this particular 'subrule', just skip it

        foreach my $r (qw{ user_category client_location client_name client_type }) {
            my $criteria_is_used  = $params->{$r} && 1;
            my $criteria          = $rule->{criteria}->{$r};
            my $rule_has_criteria = exists $rule->{criteria}->{$r};
            my $criteria_is_list  = ref $criteria eq 'ARRAY';

            my $rule_matches_criteria;
            if ($criteria_is_list) {
                $rule_matches_criteria = any { $_ eq $params->{$r} } @$criteria;
            }
            else {
                $rule_matches_criteria = $rule->{criteria}->{$r} eq $params->{$r};
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

    $params->{name} = 'PrinterConfiguration';

    my $yaml   = $c->setting($params);
    $yaml = encode('UTF-8',$yaml);

    my $config = YAML::XS::Load($yaml);
    return $config;
}

=head2 get_reservation_status

Get the status of the first reservation.

=cut

sub get_reservation_status {
    my ($c,$client) = @_;
    my $timeout = $c->setting('ReservationTimeout') ? $c->setting('ReservationTimeout') : 15 ;
    my $display = $c->setting('DisplayReservationStatusWithin') ? $c->setting('DisplayReservationStatusWithin') : 60 ;
    my $reservation= $c->model('DB::Reservation')->search(
       { 'client_id' => $client->id},
       { order_by => { -asc => 'begin_time' } }
       )->first || undef;

    my $status = undef;
    if ($reservation) {
        my $seconds = str2time($reservation->end_time) - str2time($reservation->begin_time);
        my $time_left = ($timeout * 60) > $seconds ? $seconds : ($timeout * 60);
        my $reserve = str2time($reservation->begin_time) + $time_left -time();
        my $begin = str2time($reservation->begin_time) -time();
        if($reserve >= 0 && $reserve <= $time_left) {
            $status = $reservation->user->username.'  left '.floor($reserve/60).'m'.($reserve%60).'s';
        }
        elsif($reserve > $time_left && $begin < $display * 60) {
            my $willbereserved = $reserve - $time_left;
            $status = $reservation->user->username().' in '.floor($willbereserved/60).'m'.($willbereserved%60).'s' ;
        }
    }
    return $status;
}

=head2 check_login

Check the time and the user, return the available time if possible.

=cut

sub check_login {
    my($c,$client,$user) = @_;
    my $minutes_until_closing = Libki::Hours::minutes_until_closing( $c,$client->location );
    my $timeout = $c->setting('ReservationTimeout') ? $c->setting('ReservationTimeout') : 15 ;
    my %result     = ('error' => 0, 'detail' => 0,'minutes' => 0, 'reservation' => undef );
    my $time_to_reservation = 0;
    my $reservation = $c->model('DB::Reservation')->search({ user_id => $user->id(), client_id => $client->id})->first || undef;

    # 1. Check if the time is available and get the time_to_reservation
    if(!$result{'error'}) {

        $result{'reservation'} = $reservation if($reservation);

        my $first_reservation = $c->model('DB::Reservation')->search(
                        { client_id => $client->id },
                        { order_by => { -asc => 'begin_time' } }
                        )->first || undef;

        my $minutes_timeout = $timeout < $user->minutes_allotment ? $timeout:$user->minutes_allotment;
        my $begin_time = $c->now;

        ## Calculate the time to the first reservation.
        if($first_reservation) {
            if(
              ( (str2time($first_reservation->begin_time) - 60 ) <= str2time($c->now)
              && str2time($c->now) <= ( str2time($first_reservation->begin_time) + $minutes_timeout*60 )
              && $user->id != $first_reservation->user_id
              )
             ) {
                $result{'error'} = 'RESERVED_FOR_OTHER';
            }
            else {
                $begin_time = $first_reservation->begin_time;
                $time_to_reservation = floor( (str2time($begin_time) - str2time($c->now))/60 );
            }
        }
    }

    # 2. Get the available minutes
    if(!$result{'error'}) {
        my $allotment = $user->minutes_allotment;
        my $allowance = $user->is_guest() eq 'Yes'
              ? $c->setting('DefaultGuestSessionTimeAllowance')
              : $c->setting('DefaultSessionTimeAllowance');

        my @array = ($allowance, $allotment);
        push(@array, $minutes_until_closing) if ($minutes_until_closing);
        push(@array, $time_to_reservation) if ($time_to_reservation > 0);
        my $min = min @array;

        if($min > 0) {
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

sub check_reservation
{
    my ($c,$client,$user,$begin_time) = @_;
    my $parser = DateTime::Format::Strptime->new( pattern =>'%Y-%m-%d %H:%M' );
    my %result     = ('error' => 0, 'detail' => 0, 'minutes' => 0,'allotment' => 0, 'end_time' => $parser->parse_datetime($begin_time));
    my $datetime = $parser->parse_datetime($begin_time);
    my @array;
    my $minutes_to_closing = Libki::Hours::minutes_until_closing( $c,$client->location,$parser->parse_datetime($begin_time) );
    my ( $minutes_left, $minutes ) = ( 0, 0);

    #1. Check to see if the time has been past
    if(str2time($begin_time) < str2time($c->now)) {
        $result{'error'} = 'INVALID_TIME';
    }

    #2. Check allowance
    if(!$result{'error'}) {
        my $allowance  = $c->model('DB::Setting')->find({ name => 'DefaultSessionTimeAllowance'})->value;
        if($allowance <= 0) {
           $result{'error'} = 'INVALID_TIME';
           $result{'detail'} = 'SessionTimeAlowance is 0';
        }
        else {
           push(@array, $allowance);
        }
    }

    #3. Check the closing time
    if ( !$result{'error'} && defined($minutes_to_closing) ) {
       if ($minutes_to_closing > 0 ) {
          push(@array, $minutes_to_closing);
       }
       else {
          $result{'error'} = 'CLOSING_TIME';
       }
    }

    #4. Check the existing reservations
    if(!$result{'error'}) {
        my $reservations= $c->model('DB::Reservation')->search(
        { 'client_id' => $client->id},
        {
              order_by   => { -asc => 'begin_time' },
        }
        ) || undef;

        while(my $r = $reservations->next) {
             $minutes_left = str2time($r->begin_time) - str2time($begin_time);
             if( str2time($r->begin_time) <= str2time($begin_time) && str2time($begin_time) < str2time($r->end_time) ) {
                $result{'error'} = 'INVALID_TIME';
                $result{'detail'} = 'Reserved';
                 last;
                }
             elsif($minutes_left > 0) {
               push(@array, floor($minutes_left/60));
               last;
             }
        }
    }

    #5. Check the session
    if(!$result{'error'}) {
        my $session =  $c->model('DB::Session')->find( {client_id => $client->id} );
        if($session) {
           if(str2time($begin_time) < (str2time($c->now)+$session->minutes*60)) {
              $result{'error'} = 'INVALID_TIME';
              $result{'detail'} = 'Someone else is using this client';
           }
        }
    }

    #6. Check minutes_allotment
    if(!$result{'error'}) {
        if( $user->minutes_allotment > 0 ) {
            push(@array, $user->minutes_allotment);
        }
        elsif( $user->minutes_allotment <= 0 && defined($user->minutes_allotment)) {
            $result{'error'}  = 'NO_TIME';
        }
    }

    #7. Check the minimum minutes limit preference
    if(!$result{'error'}) {
        my $minimum = $c->model('DB::Setting')->find({ name => 'MinimumReservationMinutes'})->value;
        $minimum = 1 unless $minimum;
        $minutes = min @array;
        if($minutes <  $minimum) {
           $result{'error'}  = 'INVALID_TIME';
        }
        else{
           $result{'minutes'} = $minutes;
           $result{'end_time'}  = $result{'end_time'}->add(minutes => $minutes);
        }
    }

    return %result;
}

1;
