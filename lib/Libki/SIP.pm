package Libki::SIP;

use Socket qw(:crlf);
use IO::Socket::INET;
use POSIX qw(strftime);
use Data::Dumper;

sub authenticate_via_sip {
    my ( $c, $user, $username, $password ) = @_;

    my $instance = $c->instance;
    my $config = $c->config->{instances}->{$instance} || $c->config;

    unless ($config) {
        my $yaml = $c->setting('SIPConfiguration');
        $config = YAML::XS::Load($yaml) if $yaml;
    }

    my $log = $c->log();

    my $host             = $config->{SIP}->{host};
    my $port             = $config->{SIP}->{port};
    my $timeout          = $config->{SIP}->{timout} || 15;
    my $require_sip_auth = $config->{SIP}->{require_sip_auth}
      // 1;    # Default to requiring authentication if setting doesn't exist

    $log->debug("SIP SERVER: $host:$port");
    $log->debug("require_sip_auth: $require_sip_auth");

    my $transaction_date = timestamp();

    my $terminator;
    $terminator = chr(0x0a) if $config->{SIP}->{terminator} eq "NL";
    $terminator = $CR       if $config->{SIP}->{terminator} eq "CR";
    $terminator = $CRLF     if $config->{SIP}->{terminator} eq "CRLF";
    $terminator ||= chr(0x0d);    ## Default to CR
    $log->debug( "TERMINATOR: " . $config->{SIP}->{terminator} );

    my $socket = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => $timeout,
        Type     => SOCK_STREAM
    ) or $log->fatal("ERROR in Socket Creation : $!\n");

    ## Set location to empty string if not set
    $config->{SIP}->{location} //= q{};

    my $data;
    my $patron_status_request;

    if ($require_sip_auth) {
        my $string = "9300";
        $string .= "CN" . $config->{SIP}->{username} . "|";
        $string .= "CO" . $config->{SIP}->{password} . "|";
        $string .= "CP" . $config->{SIP}->{location} . "|";

        my $str_93 = checksum($string);
        $str_93 = $string . $str_93 . $terminator;
        $log->debug("SEND: $str_93");
        $socket->send($str_93);

        my $response;
        $socket->recv( $response, 1024 );
        chomp $response;

        if ( $config->{SIP}->{enable_split_messages} ) {
            $socket->recv( $split, 1024 );
            chomp $split;
            $response .= $split;
        }
        $log->debug("READ: $response");

        my $auth    = substr( $response, 2, 1 );
        my $run_num = substr( $response, 5, 1 );

        if ( $auth == "1" ) {
            my $string = "9900302.00";
            my $final  = checksum( $string, $run_num );
            my $send99 = $string . $final . $terminator;
            $log->debug("SEND: $send99");
            $socket->send($send99);

            my ( $response, $split );
            $socket->recv( $response, 1024 );
            chomp $response;

            if ( $config->{SIP}->{enable_split_messages} ) {
                $socket->recv( $split, 1024 );
                chomp $split;
                $response .= $split;
            }

            $log->debug("READ: $response");

            if ( ( substr $response, 0, 3 ) eq '98Y' ) {
                my ( $chk, $end ) = split /\|AY/, $response;
                $chk .= "|AY";
                my $run_num = substr( $end, 0, 1 );
                $patron_status_request = talk63( $config->{SIP}->{location},
                    $username, $password, $run_num )
                  . $terminator;
            }
            else {
                return {
                    success => 0,
                    error   => 'SIP_ACS_OFFLINE',
                    user    => $user
                };
            }
        }
        else {
            return { success => 0, error => 'SIP_AUTH_FAILURE', user => $user };
        }
    }
    else {
        my $run_num = 0;
        my $string  = "9900302.00";
        my $final   = checksum( $string, $run_num );
        my $send99  = $string . $final . $terminator;
        $log->debug("SEND: $send99");
        $socket->send($send99);

        my ( $response, $split );
        $socket->recv( $response, 1024 );
        chomp $response;

        if ( $config->{SIP}->{enable_split_messages} ) {
            $socket->recv( $split, 1024 );
            chomp $split;
            $response .= $split;
        }

        $log->debug("READ: $response");

        if ( ( substr $response, 0, 3 ) eq '98Y' ) {
            my ( $chk, $end ) = split /\|AY/, $response;
            $chk .= "|AY";
            my $run_num = substr( $end, 0, 1 );
            $patron_status_request = talk63( $config->{SIP}->{location},
                $username, $password, $run_num )
              . $terminator;
        }
    }

    $log->debug("SEND: $patron_status_request");
    $socket->send( $patron_status_request . $terminator );
    $socket->recv( $data, 1024 );
    $log->debug("READ: $data");

    if ( $config->{SIP}->{enable_split_messages} ) {
        $socket->recv( $split, 1024 );
        chomp $split;
        $data .= $split;
    }

    if ( CORE::index( $data, 'BLY' ) == -1 ) {
        ## This user may have existed in SIP, but is now deleted
        ## In this case, we don't want the now deleted user to be
        ## able to log into Libki, so let's attempt to delete that
        ## username before we try to authenticate.
        $c->model('DB::User')->search( { instance => $instance,  username => $username } )->delete();
        return { success => 0, error => 'INVALID_USER', user => $user };
    }

    $log->debug("ILS verifies $username exists");

    if ( CORE::index( $data, 'CQY' ) == -1 ) {
        return {
            success => 0,
            error   => 'INVALID_PASSWORD',
            user    => $user
        };
    }

    $log->debug("ILS verfies that password for user $username matches");

    my $sip_fields = sip_message_to_hashref( $c, $data);
    $log->debug( "SIP FIELDS: " . Data::Dumper::Dumper($sip_fields) );

    my $birthdate = $sip_fields->{PB} || undef;
    $birthdate = ( join( '-', unpack( "A4A2A2", $birthdate ) ) )
      if $birthdate;

    if ($user) {    ## User authenticated and exists in Libki
        $user->set_column( 'password', $password );
        $user->set_column( 'birthdate', $birthdate );
        $user->update();
    }
    else {          ## User authenticated and does not exits in Libki
        my $minutes =
          $c->model('DB::Setting')->find({ instance => $instance, name => 'DefaultTimeAllowance' })->value;

        $user = $c->model('DB::User')->create(
            {
                instance          => $instance,
                username          => $username,
                password          => $password,
                minutes_allotment => $minutes,
                status            => 'enabled',
                birthdate         => $birthdate,
            }
        );
    }

    if ( my $deny_on = $config->{SIP}->{deny_on} ) {
        my @deny_on = ref($deny_on) eq "ARRAY" ? @$deny_on : $deny_on;

        foreach my $d (@deny_on) {
            if ( $sip_fields->{patron_status}->{$d} eq 'Y' ) {
                return { success => 0, error => uc($d), user => $user };
            }
        }

        # If the fee limit is a SIP2 field, use that field as the fee limit
        if ( my $fee_limit = $config->{SIP}->{fee_limit} ) {
            $fee_limit = $sip_fields->{$fee_limit}
              if ( $fee_limit =~ /[A-Z][A-Z]/ );

            if ( $sip_fields->{BV} > $fee_limit ) {
                return {
                    success => 0,
                    error   => 'FEE_LIMIT',
                    details => { fee_limit => $fee_limit },
                    user    => $user
                };
            }
        }
    }

    if ( my $deny_on = $config->{SIP}->{deny_on_field} ) {
        my @deny_on = ref($deny_on) eq "ARRAY" ? @$deny_on : $deny_on;

        foreach my $d (@deny_on) {
            my ( $field, $message, $value ) = split( ':', $d );

            if ( $value ) {
                if ( $sip_fields->{$field} eq $value ) {
                    return { success => 0, error => $message, user => $user };
                }
            } else {
                if ( $sip_fields->{$field} ne 'Y' ) {
                    return { success => 0, error => $message, user => $user };
                }
            }
        }

    }

    return { success => 1, user => $user, sip_fields => $sip_fields };

}

sub sip_message_to_hashref {
    my ($c, $data) = @_;

    my $log = $c->log();

    my @parts = split( /\|/, $data );

    my $fixed_fields = shift(@parts);
    my $patron_status_field = substr( $fixed_fields, 2, 14 );
    my $patron_status;
    $patron_status->{charge_privileges_denied} =
      substr( $patron_status_field, 0, 1 );
    $patron_status->{renewal_privileges_denied} =
      substr( $patron_status_field, 1, 1 );
    $patron_status->{recall_privileges_denied} =
      substr( $patron_status_field, 2, 1 );
    $patron_status->{hold_privileges_denied} =
      substr( $patron_status_field, 3, 1 );
    $patron_status->{card_reported_lost} = substr( $patron_status_field, 4, 1 );
    $patron_status->{too_many_items_charged} =
      substr( $patron_status_field, 5, 1 );
    $patron_status->{too_many_items_overdue} =
      substr( $patron_status_field, 6, 1 );
    $patron_status->{too_many_renewals} = substr( $patron_status_field, 7, 1 );
    $patron_status->{too_many_claims_of_items_returned} =
      substr( $patron_status_field, 8, 1 );
    $patron_status->{too_many_items_lost} =
      substr( $patron_status_field, 9, 1 );
    $patron_status->{excessive_outstanding_fines} =
      substr( $patron_status_field, 10, 1 );
    $patron_status->{excessive_outstanding_fees} =
      substr( $patron_status_field, 11, 1 );
    $patron_status->{recall_overdue} = substr( $patron_status_field, 12, 1 );
    $patron_status->{too_many_items_billed} =
      substr( $patron_status_field, 13, 1 );

    my $hold_items_count = substr( $fixed_fields, 37, 4 );

    pop(@parts);

    my %fields = map { substr( $_, 0, 2 ) => substr( $_, 2 ) } @parts;
    $fields{patron_status} = $patron_status;
    $fields{hold_items_count} = $hold_items_count;

    return \%fields;
}

sub timestamp {
    my $timestamp = strftime '%Y%m%d    %H%M%S', localtime;
    return $timestamp;
}

sub checksum {
    my $str     = shift;
    my $run_num = shift;
    if ( $run_num == 10 ) {
        $run_num = 0;
    }
    unless ($run_num) {
        $run_num = '0';
    }
    $run_num++;
    my $trail = "AY$run_num" . 'AZ';
    $str .= $trail;
    my $checksum = -unpack( '%16U*', $str ) & 0xFFFF;
    $trail .= sprintf '%04.4X', $checksum;
    return $trail;
}

sub talk63 {
    my ( $location, $userid, $pin, $run_num ) = @_;
    my $summary = "          ";
    my $str     = "63" . "001" . timestamp() . $summary;
    $str .= "AO" . $location . "|" . "AA$userid" . "|" . "AC" . "|";
    if ($pin) {
        $str .= "AD" . $pin . "|";
    }
    my $resp = checksum( $str, $run_num );
    return ( $str . $resp );
}

1;
