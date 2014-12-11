package Libki::SIP;

use Socket qw(:crlf);
use IO::Socket::INET;

sub authenticate_via_sip {
    my ( $c, $user, $username, $password ) = @_;

    my $terminator = ( $c->config->{SIP}->{terminator} eq 'CR' ) ? $CR : $CRLF;
    local $/ = $terminator;

    my ( $sec, $min, $hour, $day, $month, $year ) = localtime(time);
    $year += 1900;
    my $transaction_date = "$year$month$day    $hour$min$sec";

    my $host = $c->config->{SIP}->{host};
    my $port = $c->config->{SIP}->{port};

    my $login_user_id  = $c->config->{SIP}->{username};
    my $login_password = $c->config->{SIP}->{password};
    my $location_code  = $c->config->{SIP}->{location};

    my $institution_id    = $location_code;
    my $patron_identifier = $username;
    my $terminal_password = $login_password;
    my $patron_password   = $password;

    my $summary = '          ';

    my $socket = IO::Socket::INET->new("$host:$port")
      or die "ERROR in Socket Creation : $!\n";

    my $login_command =
      "9300CN$login_user_id|CO$login_password|CP$location_code|";

    print $socket $login_command . $terminator;

    my $data = <$socket>;

    if ( $data =~ '^941' ) {
        my $patron_status_request =
            "63001" 
          . $summary
          . $transaction_date . "AO"
          . $institution_id . "|AA"
          . $patron_identifier . "|AC"
          . $terminal_password . "|AD"
          . $patron_password . "|";
        print $socket $patron_status_request . $terminator;

        $data = <$socket>;

        if ( CORE::index( $data, 'BLY' ) != -1 ) {
            if ( CORE::index( $data, 'CQY' ) != -1 ) {

                if ($user) {    ## User authenticated and exists in Libki
                    $user->set_column( 'password', $password );
                    $user->update();
                }
                else {    ## User authenticated and does not exits in Libki
                    my $minutes =
                      $c->model('DB::Setting')->find('DefaultTimeAllowance')
                      ->value;

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
                }

                if ( my $fee_limit = $c->config->{SIP}->{fee_limit} ) {

             # If the fee limit is a SIP2 field, use that field as the fee limit
                    $fee_limit = $sip_fields->{$fee_limit}
                      if ( $fee_limit =~ /[A-Z][A-Z]/ );

                    if ( $sip_fields->{BV} > $fee_limit ) {
                        return { success => 0, error => 'FEE_LIMIT', details => { fee_limit => $fee_limit }, user => $user };
                    }
                }

                return { success => 1, user => $user };
            }
            else {
                return { success => 0, error => 'INVALID_PASSWORD', user => $user };
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

1;
