package Libki::LDAP;

use Net::LDAP;

sub authenticate_via_ldap {
    my ( $c, $user, $username, $password ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    my $log = $c->log();

    my $adminDn           = $c->config->{LDAP}->{adminDn};
    my $adminPwd          = $c->config->{LDAP}->{adminPwd};
    my $searchBase        = $c->config->{LDAP}->{searchBase};
    my $host              = $c->config->{LDAP}->{host};
    my $port              = $c->config->{LDAP}->{port};
    my $ldaps             = $c->config->{LDAP}->{ldaps};
    my $ldaps             = $c->config->{LDAP}->{ldaps};
    my $match_attribute   = $c->config->{LDAP}->{match_attribute};
    my $require_ldap_auth = $c->config->{LDAP}->{require_ldap_auth}
      // 1;    # Default to requiring authentication if setting doesn't exist

    my $data;
    my $patron_status_request;


    if ($require_ldap_auth) {

	my $userdn = testGuid( $username, $password, $adminDn, $adminPwd, $searchBase, $host, $port, $ldaps, $match_attribute );

        if ( $userdn ) {
    		#$log->debug("userdn: $userdn");
        }
        else {
            return { success => 0, error => 'LDAP_AUTH_FAILURE', user => $user };
        }
    }

    if ($user) {    ## User authenticated and exists in Libki
        $user->set_column( 'password', $password );
        $user->update();
    }
    else {          ## User authenticated and does not exist in Libki
        my $minutes =
          $c->model('DB::Setting')->find({ instance => $instance, name => 'DefaultTimeAllowance' })->value;

        $user = $c->model('DB::User')->create(
            {
                instance          => $instance,
                username          => $username,
                password          => $password,
                minutes_allotment => $minutes,
                status            => 'enabled',
            }
        );
    }

    if ( my $deny_on = $c->config->{LDAP}->{deny_on} ) {
        my @deny_on = ref($deny_on) eq "ARRAY" ? @$deny_on : $deny_on;

        foreach my $d (@deny_on) {
            if ( $sip_fields->{patron_status}->{$d} eq 'Y' ) {
                return { success => 0, error => uc($d), user => $user };
            }
        }
    }

    return { success => 1, user => $user };

}

sub getUserDn {
    my $ldap;
    my $guid = shift;
    my $dn;
    my $entry;

    my $adminDn = shift;
    my $adminPwd = shift;
    my $searchBase = shift;
    my $host = shift;
    my $port = shift;
    my $ldaps = shift;
    my $match_attribute = shift;

    my $filter = $match_attribute . '=' . $guid;

    if ($ldaps) {
        $ldap = Net::LDAPS->new($host, verify=>'none') or die "$@";
    } else {
        $ldap = Net::LDAP->new($host, verify=>'none') or die "$@";    
    }
    
    my $mesg = $ldap->bind ($adminDn, password=>"$adminPwd");
    
    $mesg->code && return undef;
    
    $mesg = $ldap->search(base => $searchBase, filter => "$filter" ) ; 
    #$mesg = $ldap->search(base => $searchBase, filter => "sAMAccountName=$guid" ) ; 
    $mesg->code && return undef;
    $entry = $mesg->shift_entry;
     
    if ($entry) {
        $dn = $entry->dn;
        #$entry->dump;
    }
    
    $ldap->unbind;
    
    return $dn;
}

sub testGuid {
    my $ldap;

    my $guid = shift;
    my $userPwd = shift;

    my $adminDn = shift;
    my $adminPwd = shift;
    my $searchBase = shift;
    my $host = shift;
    my $port = shift;
    my $ldaps = shift;
    my $match_attribute = shift;

    my $userDn = getUserDn($guid, $adminDn, $adminPwd, $searchBase, $host, $port, $ldaps, $match_attribute );

    return undef unless $userDn;
    
    if ($ldaps) {
        $ldap = Net::LDAPS->new($host, verify=>'none') or die "$@";
    } else {
        $ldap = Net::LDAP->new($host, verify=>'none') or die "$@";    
    }

    my $mesg = $ldap->bind ($userDn, password=>"$userPwd");
    
    if ($mesg->code) {
        # Bad Bind
        print $mesg->error . "\n";
        return undef;
    }
    
    $ldap->unbind;
    
    return $userDn;
}


1;
