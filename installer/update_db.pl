#!/usr/bin/env perl

use Modern::Perl;

use Data::Dumper;
use File::Basename;
use File::Find::Rule;
use File::Slurp;
use FindBin;
use Getopt::Long;
use Pod::Usage;
use SQL::Script;
use Try::Tiny;

use Libki;

my $c = Libki->new();

my $schema = $c->schema;

my $dbh = $schema->storage->dbh;

my $schema_version = $schema->schema_version();

my $db_version;
try {
    my $sth = $dbh->prepare(q{SELECT * FROM settings WHERE name = 'Version'});
    $sth->execute();
    my $setting = $sth->fetchrow_hashref;
    $db_version = $setting->{value};
}
catch {
    $db_version = '0.0.0';
};

my @version_dirs =
  sort( File::Find::Rule->directory()->in("$FindBin::RealBin/versions") );
shift(@version_dirs);

foreach my $version_dir (@version_dirs) {
    my $major_version = ( split( '/', $version_dir ) )[-1];

    if ( $db_version gt '0.0.0' && $db_version lt '3.0.0' ) {
        print "Welcome to the Libki Database Updater.\n\n";
        print "Unfortunately it isn't possible to update your version of Libki this way.\n";
        print "You will need to use the r19.08 release first. It's located at https://github.com/Libki/libki-server/archive/r19.08.zip.\n";
        print "Run update_db.pl from there, and when that is done it will be possible to use this updater.\n\n";
        print "As root, run:\n\n";
        print "wget https://github.com/Libki/libki-server/archive/r19.08.zip\n";
        print "unzip r19.08.zip\n";
        print "./r19.08/installer/update_db.pl\n\n";
        print "It is HIGHLY adviceable that you do a backup first.\n";
        print "See https://manual.libki.org for more information on how to do backups.\n";

        exit 0;
    }

    my $version;

    my @files =
      sort( File::Find::Rule->name( '*.pl', '*.sql' )->in($version_dir) );

    foreach my $file (@files) {
        my ( $name, $path, $suffix ) = fileparse( $file, qw( .pl .sql ) );

        my $filepath = ( split( '/', $file ) )[-1];

        my @subversion_and_name = split(/_/, $filepath);

        $version = $major_version . '.' . @subversion_and_name[0];

	next unless ( $version gt $db_version );

        print "\nInstalling version $version\n\n";
        print "Running update $name$suffix\n";

        if ( $suffix eq '.pl' ) {
            my $c = eval( read_file($file) );
            die $@ if ($@);
        }
        elsif ( $suffix eq '.sql' ) {
            my $script = SQL::Script->new();
            $script->read($file);
            my @statements = $script->statements();

            foreach my $s (@statements) {
                try {
                    $dbh->do($s);
                }
                catch {
                    print "UPDATE FAILED IN FILE $file: $_";
                }
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

=head1 FUNCTIONS

=head2 table_exists

=cut

sub table_exists {
    my ( $table, $dbh );
    eval {
                local $dbh->{PrintError} = 0;
                local $dbh->{RaiseError} = 1;
                $dbh->do(qq{SELECT * FROM $table WHERE 1 = 0 });
            };
    return 1 unless $@;
    return 0;
}

=head2 foreign_key_exists

=cut

sub foreign_key_exists {
    my ( $table_name, $constraint_name, $dbh ) = @_;
    my (undef, $infos) = $dbh->selectrow_array(qq|SHOW CREATE TABLE $table_name|);
    return $infos =~ m|CONSTRAINT `$constraint_name` FOREIGN KEY|;
}

=head2 index_exists

=cut

sub index_exists {
    my ( $table_name, $key_name, $dbh ) = @_;
    my ($exists) = $dbh->selectrow_array(
        qq|
        SHOW INDEX FROM $table_name
        WHERE key_name = ?
        |, undef, $key_name
    );
    return $exists;
}

=head2 column_exists

=cut

sub column_exists {
    my ( $table_name, $column_name, $dbh ) = @_;
    my $dbh = C4::Context->dbh;
    my ($exists) = $dbh->selectrow_array(
        qq|
        SHOW COLUMNS FROM $table_name
        WHERE Field = ?
        |, undef, $column_name
    );
    return $exists;
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
