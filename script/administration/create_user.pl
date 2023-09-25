#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;

use Libki;
use Libki::Utils::User;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'instance|i=s', "the instance for the user to exist on", { default  => q{} } ],
    [ 'username|u=s', "the username for this user, required",  { required => 1 } ],
    [ 'password|p=s', "the password for this user" ],
    [ 'minutes|m=i',  "number of minutes for this user" ],
    [ 'admin|a',      "makes the user an admin" ],
    [ 'superadmin|s', "makes the user a superadmin" ],
    [],
    [ 'verbose|v', "print extra stuff" ],
);

print( $usage->text ), exit unless ( $opt->username );

my $c    = Libki->new();
my $user = Libki::Utils::User::create_or_update_user(
    $c,
    {
        instance   => $opt->instance,
        username   => $opt->username,
        password   => $opt->password,
        minutes    => $opt->minutes,
        admin      => $opt->admin,
        superadmin => $opt->superadmin,
    }
);

say "User created" if $user;
say "User not created" unless $user;
if ( $user && $opt->verbose ) {
  say "User Id: " . $user->id;
  say "Username: " . $user->username;
  say "Instance: " . $user->instance;
  say "Minutes: " . $user->minutes($c);
  say "Is Admin: " . ( $user->has_role(q{admin}) ? 'Yes' : 'No' );
  say "Is Admin: " . ( $user->has_role(q{superadmin}) ? 'Yes' : 'No' );
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
