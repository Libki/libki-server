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
        my $patron_status_request = "63001"
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

                if ($user) {   ## User authenticated and exists in Libki
                    $user->set_column( 'password', $password );
                    $user->update();
                }
                else { ## User authenticated and does not exits in Libki
                    my $minutes =
                      $c->model('DB::Setting')
                      ->find('DefaultTimeAllowance')->value;

                    $user = $c->model('DB::User')->create(
                        {
                            username => $username,
                            password => $password,
                            minutes  => $minutes,
                            status   => 'enabled',
                        }
                    );
                }

                return 1;
            }
            else {
                return ( 0, 'INVALID_PASSWORD' );
            }
        }
        else {
            ## This user may have existing in SIP, but is now deleted
            ## In this case, we don't want the now deleted user to be
            ## able to log into Libki, so let's attempt to delete that
            ## username before we try to authenticate.
            $c->model('DB::User')
              ->search( { username => $username } )->delete();

            return ( 0, 'INVALID_USER' );
        }
    }
    else {
        return ( 0, 'CONNECTION_FAILURE' );
    }

}

1;
