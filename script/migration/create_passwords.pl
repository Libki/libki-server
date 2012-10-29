#!/usr/bin/perl

use strict;
use warnings;

use Config::JFDI;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki::Model::DB;
use Libki::Schema::DB;

my $config =
  Config::JFDI->new( file => "$FindBin::Bin/../../libki_local.conf", no_06_warning => 1 );
my $config_hash  = $config->get;
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my @users = $schema->resultset('User')->all;

foreach my $user (@users) {
    print "Working on " . $user->username() . "...\n";

    $user->password( $user->username() );
    $user->update();
}

print "Done. Passwords are set to usernames.\n\n";

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
