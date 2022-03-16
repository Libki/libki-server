package Libki::Auth;

use Modern::Perl;

use JSON qw(decode_json);

=head2 authenticate_user

Checks a username and password combo for validity

=cut

sub authenticate_user {
    my ($params)        = @_;
    my $c                = $params->{context};
    my $username         = $params->{username};
    my $password         = $params->{password};
    my $no_external_auth = $params->{no_external_auth};

    my $external_auth = !$no_external_auth;

    my $instance = $c->instance;
    my $config   = $c->instance_config;
    my $log      = $c->log();

    my $user = $c->model('DB::User')
      ->single( { instance => $instance, username => $username } );

    ## If SIP is enabled, try SIP first, unless we have a guest or staff account
    my ( $success, $error, $sip_fields ) = ( 1, undef, undef );
    if ( $external_auth && $config->{SIP}->{enable} ) {
        if (
            !$user
            || (   $user
                && $user->is_guest() eq 'No'
                && !$c->check_any_user_role( $user,
                    qw/admin superadmin/ ) )
          )
        {
            $log->debug( __PACKAGE__ . " attempting SIP authentication for $username" );

            my $ret =
              Libki::SIP::authenticate_via_sip( $c, $user, $username,
                $password );
            $success = $ret->{success};
            $error   = $ret->{error};
            $user    = $ret->{user};

            # Not strictly needed, but if we re-use this sub in Client/v1_0.pm it will be good to have
            $sip_fields = $ret->{sip_fields};
            if ($sip_fields) {
                $c->stash(
                    hold_items_count => $sip_fields->{hold_items_count}
                );
            }
        }
    }

    ## If LDAP is enabled, try LDAP, unless we have a guest or staff account
    if ( $external_auth && $config->{LDAP}->{enable} ) {
        $log->debug( __PACKAGE__ . " attempting LDAP authentication for $username" );
        if (
            !$user
            || (   $user
                && $user->is_guest() eq 'No'
                && !$c->check_any_user_role( $user,
                    qw/admin superadmin/ ) )
          )
        {
            my $ret =
              Libki::LDAP::authenticate_via_ldap( $c, $user, $username,
                $password );
            $success = $ret->{success};
            $error   = $ret->{error};
            $user    = $ret->{user};
        }
    }

    ## Process client requests
    if ($success) {
        if (
            $c->authenticate(
                {
                    username => $username,
                    password => $password,
                    instance => $instance,
                }
            )
          )
        {
            $success = 1;
        }
        else {
            $success = 0;
            $error = 'BAD_LOGIN';
        }
    }

    return {
        success => $success,
        error   => $error,
        user    => $user,
    };
}

=head2 validate_api_key

Checks that a key is valid for the scope requested

=cut

sub validate_api_key {
    my ($params) = @_;
    my $c        = $params->{context};
    my $api_key  = $params->{key};
    my $type     = $params->{type};

    my $instance = $c->instance;
    my $config   = $c->instance_config;
    my $log      = $c->log();

    my $json = $c->setting( 'ApiKeys' );
    return 0 unless $json;

    my $data = decode_json( $json );
    foreach my $k ( @$data ) {
        next if $k->{key} ne $api_key;
        next if $type ne '*' && $k->{type} ne $type;
        return 1;
    }

    return 0
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

1;
