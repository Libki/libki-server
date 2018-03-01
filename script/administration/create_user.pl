#!/usr/bin/perl

use strict;
use warnings;

use Config::ZOMG;
use Getopt::Long::Descriptive;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki::Schema::DB;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'username|u=s', "the username for this user, required" ],
    [ 'password|p=s', "the password for this user" ],
    [ 'minutes|m=s',  "number of minutes for this user" ],
    [ 'admin|a',      "makes the user an admin" ],
    [ 'superadmin|s', "makes the user a superadmin" ],
    [],
    [ 'verbose|v', "print extra stuff" ],
);

print( $usage->text ), exit unless ( $opt->username );

my $config = Config::ZOMG->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
);
my $config_hash  = $config->load();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my $user_rs = $schema->resultset('User');

my $user = $user_rs->find( { username => $opt->username } );

if ($user) {
    $user->set_column( 'password', $opt->password );
    $user->update();
}
else {
    $user = $user_rs->create(
        {
            username          => $opt->username,
            password          => $opt->password,
            minutes_allotment => $opt->minutes
              || $schema->resultset('Setting')->find('DefaultTimeAllowance')
              ->value(),
            status          => 'enabled',
            is_troublemaker => 'No',
        }
    );
}
if ( $opt->superadmin ) {
    my $role =
      $schema->resultset('Role')->search( { role => 'superadmin' } )->single();

    $schema->resultset('UserRole')->update_or_create(
        {
            role_id => $role->id,
            user_id => $user->id,
        }
    );
}

if ( $opt->admin || $opt->superadmin ) {
    my $role =
      $schema->resultset('Role')->search( { role => 'admin' } )->single();

    $schema->resultset('UserRole')->update_or_create(
        {
            role_id => $role->id,
            user_id => $user->id,
        }
    );
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
