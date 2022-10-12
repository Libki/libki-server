#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;

use Libki;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'instance|i=s', "the instance to be created, required", { required => 1 } ],
    [],
    [ 'verbose|v+', "print extra stuff" ],
);

print( $usage->text ), exit unless ( $opt->instance );

my $c      = Libki->new();
my $schema = $c->schema;
my $rs     = $schema->resultset('Setting');

my $i = $opt->instance;
say qq{Creating instance '$i'} if $opt->verbose;

my $defaults = {
    'AutomaticTimeExtensionAt'           => '',
    'AutomaticTimeExtensionLength'       => '',
    'AutomaticTimeExtensionRenewal'	 => '0',
    'AutomaticTimeExtensionUnless'       => 'this_reserved',
    'AutomaticTimeExtensionUseAllotment' => 'no',
    'BatchGuestPassPasswordLabel'        => 'Password: ',
    'BatchGuestPassUsernameLabel'        => 'Username: ',
    'ClientBehavior'                     => 'FCFS+RES',
    'CurrentGuestNumber'                 => '1',
    'CustomJsAdministration'             => '',
    'CustomJsPublic'                     => '',
    'DataRetentionDays'                  => '',
    'DefaultGuestSessionTimeAllowance'   => '60',
    'DefaultGuestTimeAllowance'          => '60',
    'DefaultSessionTimeAllowance'        => '60',
    'DefaultTimeAllowance'               => '60',
    'GuestBatchCount'                    => '20',
    'PostCrashTimeout'                   => '5',
    'PrintJobRetentionDays'              => '0',
    'ReservationShowUsername'            => '0',
    'ReservationTimeout'                 => '15',
    'ThirdPartyURL'                      => '',
    'UserCategories'                     => '',
    'EnableClientSessionPausing'         => 0,
    'BatchGuestPassTemplate'             => q{<html>
  <head>
    <style type="text/css">[% batch_guest_pass_custom_css %]</style>
  </head>
  <body>
    [% FOREACH g IN guests %]
      <p class="guest-pass">
        <p class="guest-pass-username">
          <span class="guest-pass-username-label">[% batch_guest_pass_username_label %]</span><span class="guest-pass-username-content">[% g.username %]</span>
        </p>
        <p class="guest-pass-password">
          <span class="guest-pass-password-label">[% batch_guest_pass_password_label %]</span><span class="guest-pass-password-content">[%g. password %]</span>
        </p>
      </p>
      <br/>
    [% END %]
  </body>
</html>},
};

while ( my ( $name, $value ) = each %$defaults ) {
    say qq{Creating setting $name with default value '$value'} if $opt->verbose > 1;
    $rs->find_or_create( { instance => $i, name => $name, value => $value } );
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
