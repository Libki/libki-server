#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Pod::Usage;
use Getopt::Long;
use Config::JFDI;

use Libki::Schema::DB;

my $config = Config::JFDI->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
    no_06_warning => 1
);
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my $schema_version = $schema->schema_version();
my $db_version     = $schema->get_db_version();

if ($db_version) {
    print "\nUpgrading database schema from $db_version to $schema_version\n";
    $schema->upgrade();
}
else {    # schema is unversioned
    print "\nInstalling database schema version $schema_version\n";
    $schema->deploy();
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
