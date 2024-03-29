package Libki::Controller::Public::Login;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

LibkiServer::Controller::Public::Login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

Login logic

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # Get the username and password from form
    my $username  = $c->request->params->{username};
    my $password  = $c->request->params->{password};
    my $submitted = $c->request->params->{submitted} || 0;

    my $instance = $c->instance;
    my $auth = 1;
    my $config = $c->instance_config;
    # If the username and password values were found in form
    if ( $username && $password ) {
        my $user = $c->model('DB::User')->single( { instance => $instance, username => $username } );

        if ( $config->{SIP}->{enable} ) {
            if ( !$user
                || ( $user && $user->creation_source eq 'SIP' && $user->is_guest() eq 'No' ) )
            {
                my $ret = Libki::SIP::authenticate_via_sip( $c, $user, $username, $password );
                $auth = $ret->{success};
            }
        }
        elsif ( $config->{LDAP}->{enable} ) {
            if ( !$user
                || ( $user && $user->creation_source eq 'LDAP' && $user->is_guest() eq 'No' ) )
            {
                my $ret = Libki::LDAP::authenticate_via_ldap( $c, $user, $username, $password );
                $auth = $ret->{success};
            }
        }

        if ( $auth ) {
            $auth = $c->authenticate( { username => $username, password => $password, instance => $instance } );
        }

        if ( $auth ) {
            $c->response->redirect(
                $c->uri_for(
                    $c->controller('Public')->action_for('index')
                )
            );
        }
        else {
            $c->stash( error_message => "Wrong username or password." );
        }
    }
    else {
        if ($submitted) {

            # Set an error message
            $c->stash( error_message => "Empty username or password." );
        }
    }

    # If either of above don't work out, send to the login page
    $c->stash( template => 'public/login.tt' );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

This file is part of Libki.

Libki is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as 
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.
                
Libki is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
                                                
You should have received a copy of the GNU General Public License
along with Libki.  If not, see <http://www.gnu.org/licenses/>.
                                                
=cut

__PACKAGE__->meta->make_immutable;

1;
