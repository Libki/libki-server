#!/usr/bin/env perl

use Modern::Perl;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Pod::Usage;
use Getopt::Long;
use Config::ZOMG;
use File::Find::Rule;
use File::Basename;
use File::Slurp;
use Data::Dumper;
use SQL::Script;
use Try::Tiny;

use Libki::Schema::DB;

my $config = Config::ZOMG->new(
    file          => "$FindBin::Bin/../libki_local.conf",
);
my $config_hash  = $config->load();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my $dbh = $schema->storage->dbh;

my $schema_version = $schema->schema_version();

my $db_version;
try {
    $db_version = $schema->resultset('Setting')->search( { name => 'Version' } )->next->value;
}
catch {
    $db_version = '00.00.00.000';
};

my @version_dirs =
  sort( File::Find::Rule->directory()->in("$FindBin::RealBin/versions") );
shift(@version_dirs);

foreach my $version_dir (@version_dirs) {
    my $version = ( split( '/', $version_dir ) )[-1];

    next unless ( $version gt $db_version );

    print "Installing version $version\n";

    my @files =
      sort( File::Find::Rule->name( '*.pl', '*.sql' )->in($version_dir) );

    foreach my $file (@files) {
        my ( $name, $path, $suffix ) = fileparse( $file, qw( .pl .sql ) );
        print "Running script $name\n";

        if ( $suffix eq '.pl' ) {
            my $c = eval( read_file($file) );
            die $@ if ($@);
        }
        elsif ( $suffix eq '.sql' ) {
            my $script = SQL::Script->new();
            $script->read($file);
            my @statements = $script->statements();

            foreach my $s (@statements) {
                $dbh->do($s);
            }
        }
    }
    
    $schema->storage->dbh_do(
      sub {
        my ($storage, $dbh, $version) = @_;
        $dbh->do("REPLACE INTO settings ( name, value ) VALUES ( ?, ? )", undef, 'Version', $version );
      },
      $version
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
