package Libki::SIP;

use feature 'say';

use Data::Dumper;
use IO::Socket::INET;
use POSIX qw(strftime);
use Socket qw(:crlf);

=head2 authenticate_via_sip

Connects to an external SIP server with a given username and password.
Returns a hashref with keys 'success' and 'ERROR' among other data.

=cut

sub authenticate_via_sip {
    my ( $c, $user, $username, $password, $test_mode, $admin_auth ) = @_;

    $password //= q{};

    my $instance = $c->instance;
    my $config = $c->instance_config;

    my $log = $c->log();

    my $host             = $config->{SIP}->{host};
    my $port             = $config->{SIP}->{port};
    my $timeout          = $config->{SIP}->{timout} || 15;
    my $require_sip_auth = $config->{SIP}->{require_sip_auth}
      // 1;    # Default to requiring authentication if setting doesn't exist

    $log->debug("SIP SERVER: $host:$port");
    say "SIP SERVER: $host:$port" if $test_mode;
    $log->debug("require_sip_auth: $require_sip_auth");
    say "require_sip_auth: $require_sip_auth" if $test_mode;

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
        )
        or $log->fatal("ERROR in Socket Creation : $!\n")
        && ( $test_mode && die "ERROR in Socket Creation : $!\n" );

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
        say "SEND: $str_93" if $test_mode;
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
        say "READ: $response" if $test_mode;

        my $auth    = substr( $response, 2, 1 );
        my $run_num = substr( $response, 5, 1 );

        if ( $auth == "1" ) {
            my $string = "9900302.00";
            my $final  = checksum( $string, $run_num );
            my $send99 = $string . $final . $terminator;
            $log->debug("SEND: $send99");
            say "SEND: $send99" if $test_mode;
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
            say "READ: $response" if $test_mode;

            if ( ( substr $response, 0, 3 ) eq '98Y' ) {
                my ( $chk, $end ) = split /\|AY/, $response;
                $chk .= "|AY";
                my $run_num = substr( $end, 0, 1 );
                $patron_status_request = talk63( $config->{SIP}->{location},
                    $username, $password, $run_num )
                  . $terminator;
            }
            else {
                $log->error("ERROR: SIP Server is offline!");
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
        say "SEND: $send99" if $test_mode;
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
        say "READ: $response" if $test_mode;

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
    say "SEND: $patron_status_request" if $test_mode;
    $socket->send( $patron_status_request . $terminator );
    $socket->recv( $data, 1024 );

    if ( $config->{SIP}->{enable_split_messages} ) {
        $socket->recv( $split, 1024 );
        chomp $split;
        $data .= $split;
    }

    $log->debug("READ: $data");
    say "READ: $data" if $test_mode;

    if ( CORE::index( $data, 'BLN' ) != -1 ) {
        ## This user may have existed in SIP, but is now deleted
        ## In this case, we don't want the now deleted user to be
        ## able to log into Libki, so let's attempt to delete that
        ## username before we try to authenticate.
        my $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );
        if ($user) {
            my $is_admin = $c->check_any_user_role( $user, qw/admin superadmin/ );
            $log->debug(
                sprintf(
                    "User %s is admin account and should not be deleted: %s",
                    $user->id, $is_admin
                )
            );

            unless ($is_admin) {
                $c->model('DB')->txn_do(
                    sub {
                        $user->delete;

                        $c->model('DB::Statistic')->create(
                            {
                                instance   => $instance,
                                username   => $username,
                                action     => 'USER_DELETE',
                                created_on => $c->now,
                                info       => to_json(
                                    {
                                        deleted_from => 'SIP',
                                        user_id      => $user->id,
                                    }
                                ),
                            }
                        );
                    }
                );
            }
        }
        return { success => 0, error => 'INVALID_USER', user => $user };
    }

    $log->debug("ILS verifies $username exists");

    unless ( $c->setting('EnableClientPasswordlessMode') || $config->{SIP}->{no_password_check} || $admin_auth ) {
        if ( CORE::index( $data, 'CQY' ) == -1 ) {
            return {
                success => 0,
                error   => 'INVALID_PASSWORD',
                user    => $user
            };
        }
    }

    $log->debug("ILS verfies that password for user $username matches");

    my $sip_fields = sip_message_to_hashref( $c, $data, $config );
    $log->debug( "SIP FIELDS: " . Data::Dumper::Dumper($sip_fields) );

    my $birthdate_field = $c->config->{SIP}->{birthdate_field} || 'PB';
    my $birthdate       = $sip_fields->{$birthdate_field}      || undef;
    $birthdate = ( join( '-', unpack( "A4A2A2", $birthdate ) ) )
        if $birthdate;

    my ( $lastname, $firstname );
    unless ( $c->config->{SIP}->{skip_import_personal_name} ) {
        ( $lastname, $firstname )
            = split( $c->config->{SIP}->{pattern_personal_name}, $sip_fields->{AE} );

        $lastname  =~ s/^\s+//;
        $firstname =~ s/^\s+//;

        ( $lastname, $firstname ) = ( $firstname, $lastname )
            if $c->config->{SIP}->{pattern_personal_name_reverse};
    }

    my $category = $sip_fields->{ $c->config->{SIP}->{category_field} };
    $c->add_user_category($category) if $category;

    if ($user) {    ## User authenticated and exists in Libki
        $user->set_column( 'lastname',  $lastname );
        $user->set_column( 'firstname', $firstname );
        $user->set_column( 'category',  $category );
        $user->set_column( 'password',  $password );
        $user->set_column( 'birthdate', $birthdate );
        $user->set_column( 'password',  $password ); # Set password in case user was created by staff reservation
        $user->update();
    }
    else {          ## User authenticated and does not exits in Libki
        $user = $c->model('DB::User')->create(
            {
                instance          => $instance,
                username          => $username,
                password          => $password,
                status            => 'enabled',
                birthdate         => $birthdate,
                lastname          => $lastname,
                firstname         => $firstname,
                category          => $category,
                creation_source   => 'SIP',
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

            if ($value) {
                if ( $sip_fields->{$field} eq $value ) {
                    return { success => 0, error => $message, user => $user };
                }
                elsif ( $sip_fields->{$field} =~ /$value/ ) {
                    return { success => 0, error => $message, user => $user };
                }
            }
            else {
                if ( $sip_fields->{$field} ne 'Y' ) {
                    return { success => 0, error => $message, user => $user };
                }
            }
        }

    }

    return { success => 1, user => $user, sip_fields => $sip_fields };

}

=head2 sip_message_to_hashref

Converts a raw SIP message into a more useful Perl structure.

=cut

sub sip_message_to_hashref {
    my ( $c, $data, $config ) = @_;

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

    pop(@parts);

    my %fields = map { substr( $_, 0, 2 ) => substr( $_, 2 ) } @parts;
    $fields{patron_status} = $patron_status;

    $fields{hold_items_count} = 0;
    my $hold_notification = $config->{SIP}->{hold_notification} // 1;
    if ($hold_notification) {
        my $hold_items_count        = substr( $fixed_fields, 37, 4 );
        my $unavailable_holds_count = substr( $fixed_fields, 57, 4 );

        my $ils = $config->{SIP}->{ILS};
        $fields{hold_items_count}
            = $ils eq 'Koha'      ? $hold_items_count
            : $ils eq 'Evergreen' ? $hold_items_count - $unavailable_holds_count
            :                       $hold_items_count;
    }

    return \%fields;
}

=head2 timestamp

Returns the current time in a format acceptable for SIP

=cut

sub timestamp {
    my $timestamp = strftime '%Y%m%d    %H%M%S', localtime;
    return $timestamp;
}

=head2 checksum

Generates a SIP checksum for a given string

=cut

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

=head2 talk63

Sends a 63 patron information request.
Returns the raw message with checksum added.

=cut

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
