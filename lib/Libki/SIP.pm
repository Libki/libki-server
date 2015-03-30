package Libki::SIP;

use Socket qw(:crlf);
use IO::Socket::INET;
use POSIX qw(strftime);
use Data::Dumper;

sub authenticate_via_sip {
    my ( $c, $user, $username, $password ) = @_;
    my $terminator;
    my $data;
    my $transaction_date = timestamp();
    my $host             = $c->config->{SIP}->{host};
    my $port             = $c->config->{SIP}->{port};
    my $patron_status_request;
    if ( $c->config->{SIP}->{terminator} eq "NL" ) {
        $terminator = chr(0x0a);
    }
    else { $terminator = chr(0x0d) }
    my $socket = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => '15',
        Type     => SOCK_STREAM
    ) or die "ERROR in Socket Creation : $!\n";
    if ( $c->config->{SIP}->{require_sip_auth} == 0 ) {
        my $run_num = 0;
        my $string  = "9900302.00";
        my $final   = checksum( $string, $run_num );
        my $send99  = $string . $final . $terminator;
        $socket->send($send99);
        my ( $response, $split );
        $socket->recv( $response, 1024 );
        chomp $response;

        if ( $c->config->{SIP}->{enable_split_messages} ) {
            $socket->recv( $split, 1024 );
            chomp $split;
            $response .= $split;
        }
        if ( ( substr $response, 0, 3 ) eq '98Y' ) {
            my ( $chk, $end ) = split /\|AY/, $response;
            $chk .= "|AY";
            my $run_num = substr( $end, 0, 1 );
            $patron_status_request = talk63( $c->config->{SIP}->{location},
                $username, $password, $run_num )
              . $terminator;
        }
    }
    if ( $c->config->{SIP}->{require_sip_auth} != 0 ) {
        my $string = "9300";
        $string .= "CN" . $c->config->{SIP}->{username} . "|";
        $string .= "CO" . $c->config->{SIP}->{password} . "|";
        $string .= "CP";
        if ( $c->config->{SIP}->{location} ) {
            $string .= $c->config->{SIP}->{location} . "|";
        }
        else {
            $string .= "" . "|";
        }
        my $str_93 = checksum($string);
        $str_93 = $string . $str_93 . $terminator;
        $socket->send($str_93);
        my $response;
        $socket->recv( $response, 1024 );
        chomp $response;
        if ( $c->config->{SIP}->{enable_split_messages} ) {
            $socket->recv( $split, 1024 );
            chomp $split;
            $response .= $split;
        }
        my $auth    = substr $response, 2, 1;
        my $run_num = substr $response, 5, 1;
        if ( $auth == "1" ) {
            my $string = "9900302.00";
            my $final  = checksum( $string, $run_num );
            my $send99 = $string . $final . $terminator;
            $socket->send($send99);
            my ( $response, $split );
            $socket->recv( $response, 1024 );
            chomp $response;
            if ( $c->config->{SIP}->{enable_split_messages} ) {
                $socket->recv( $split, 1024 );
                chomp $split;
                $response .= $split;
            }
            if ( ( substr $response, 0, 3 ) eq '98Y' ) {
                my ( $chk, $end ) = split /\|AY/, $response;
                $chk .= "|AY";
                my $run_num = substr( $end, 0, 1 );
                $patron_status_request = talk63( $c->config->{SIP}->{location},
                    $username, $password, $run_num )
                  . $terminator;
            }
        }
        else {
            return { success => 0, error => 'SIP_AUTH_FAILURE', user => $user };
        }
    }

    $socket->send( $patron_status_request . $terminator );
    $socket->recv( $data, 1024 );
    if ( $c->config->{SIP}->{enable_split_messages} ) {
        $socket->recv( $split, 1024 );
        chomp $split;
        $data .= $split;
    }
    if ( CORE::index( $data, 'BLY' ) != -1 ) {
        if ( CORE::index( $data, 'CQY' ) != -1 ) {

            if ($user) {    ## User authenticated and exists in Libki
                $user->set_column( 'password', $password );
                $user->update();
            }
            else {          ## User authenticated and does not exits in Libki
                my $minutes =
                  $c->model('DB::Setting')->find('DefaultTimeAllowance')->value;

                $user = $c->model('DB::User')->create(
                    {
                        username          => $username,
                        password          => $password,
                        minutes_allotment => $minutes,
                        status            => 'enabled',
                    }
                );
            }

            my $sip_fields = sip_message_to_hashref($data);

            if ( my $deny_on = $c->config->{SIP}->{deny_on} ) {
                my @deny_on = ref($deny_on) eq "ARRAY" ? @$deny_on : $deny_on;

                foreach my $d (@deny_on) {
                    if ( $sip_fields->{patron_status}->{$d} eq 'Y' ) {
                        return { success => 0, error => uc($d), user => $user };
                    }
                }

                #}

                if ( my $fee_limit = $c->config->{SIP}->{fee_limit} ) {

             # If the fee limit is a SIP2 field, use that field as the fee limit
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

                return { success => 1, user => $user };
            }
            else {
                return {
                    success => 0,
                    error   => 'INVALID_PASSWORD',
                    user    => $user
                };
            }
        }
        else {
            ## This user may have existing in SIP, but is now deleted
            ## In this case, we don't want the now deleted user to be
            ## able to log into Libki, so let's attempt to delete that
            ## username before we try to authenticate.
            $c->model('DB::User')->search( { username => $username } )
              ->delete();

            return { success => 0, error => 'INVALID_USER', user => $user };
        }
    }
    else {
        return { success => 0, error => 'CONNECTION_FAILURE', user => $user };
    }

}

sub sip_message_to_hashref {
    my ($data) = @_;

    my @parts = split( /\|/, $data );

    my $patron_status_field = shift(@parts);
    $patron_status_field = substr( $patron_status_field, 2, 14 );
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

    pop(@parts);

    my %fields = map { substr( $_, 0, 2 ) => substr( $_, 2 ) } @parts;
    $fields{patron_status} = $patron_status;

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
