#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use DBIx::Class::DeploymentHandler;
use SQL::Translator;
use Config::JFDI;

use Libki::Schema::DB;

my $config =
  Config::JFDI->new( file => "$FindBin::Bin/../../libki_local.conf", no_06_warning => 1 );
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = 'Libki::Schema::DB';

my $version = eval "use $schema; $schema->VERSION" or die $@;

print "Processing version $version of $schema...\n";

my $s = $schema->connect($connect_info)
  || die("Couldn't Connect to DB");

my $dh = DBIx::Class::DeploymentHandler->new( {
        schema              => $s,
        script_directory => "$FindBin::Bin/../../sql",
        databases           => [qw/ SQLite PostgreSQL MySQL /],
        sql_translator_args => { add_drop_table => 0, },
    } );

print "Generating deployment script...\n";
$dh->prepare_install;

if ( $version > 1 ) {
    print "Generating upgrade script...\n";
    $dh->prepare_upgrade( {
            from_version => $version - 1,
            to_version   => $version,
            version_set  => [ $version - 1, $version ],
        } );

    print "Generating downgrade script...\n";
    $dh->prepare_downgrade( {
            from_version => $version,
            to_version   => $version - 1,
            version_set  => [ $version, $version - 1 ],
        } );
}

print "Done\n";

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
