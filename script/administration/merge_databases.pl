#!/usr/bin/perl

use Modern::Perl;

use Data::Dumper;
use Getopt::Long::Descriptive;

use DBI;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'from-database|fd=s', "Database to move data from, required"     , { required => 1 } ],
    [ 'from-hostname|fh=s', "Database host to move data from, required", { required => 1 } ],
    [ 'from-port|fP=s'    , "Database port to move data from, required", { required => 1 } ],
    [ 'from-user|fu=s'    , "Database user to move data from, required", { required => 1 } ],
    [ 'from-password|fp=s', "Database user to move data from, required", { required => 1 } ],
    [],
    [ 'to-database|td=s', "Database to move data to, required"     , { required => 1 } ],
    [ 'to-hostname|th=s', "Database host to move data to, required", { required => 1 } ],
    [ 'to-port|tP=s'    , "Database port to move data to, required", { required => 1 } ],
    [ 'to-user|tu=s'    , "Database user to move data to, required", { required => 1 } ],
    [ 'to-password|tp=s', "Database user to move data to, required", { required => 1 } ],
    [],
    [ 'verbose|v+', "print extra stuff" ],
);

my ( $from_database, $from_hostname, $from_port, $from_user, $from_password ) = ( $opt->from_database, $opt->from_hostname, $opt->from_port, $opt->from_user, $opt->from_password );
my ( $to_database, $to_hostname, $to_port, $to_user, $to_password ) = ( $opt->to_database, $opt->to_hostname, $opt->to_port, $opt->to_user, $opt->to_password );

my %attr = (
    RaiseError => 1,    # error handling enabled
    AutoCommit => 0,    # transaction enabled
);

my $from_dsn = "DBI:mysql:database=$from_database;host=$from_hostname;port=$from_port";
my $from_dbh = DBI->connect( $from_dsn, $from_user, $from_password, \%attr );

my $to_dsn = "DBI:mysql:database=$to_database;host=$to_hostname;port=$to_port";
my $to_dbh = DBI->connect( $to_dsn, $to_user, $to_password, \%attr );

# Verify both tables have matching tables;
my $from_query = qq{SELECT table_name FROM information_schema.tables where table_schema='$from_database'};
my @from_tables = @{$from_dbh->selectcol_arrayref( $from_query )};

my $to_query = qq{SELECT table_name FROM information_schema.tables where table_schema='$to_database'};
my @to_tables = @{$to_dbh->selectcol_arrayref( $to_query )};

unless ( lists_equal( \@from_tables, \@to_tables ) ) {
    say "Database tables do not match!";
    say "From tables: " . Data::Dumper::Dumper( \@from_tables );
    say "To tables: " . Data::Dumper::Dumper( \@to_tables );
    $from_dbh->rollback();
    $from_dbh->disconnect();
    $to_dbh->rollback();
    $to_dbh->disconnect();
    exit(1);
} else {
    say "Database tables match!" if $opt->verbose;
}

# Verify each table pair in the databases have matching columns
foreach my $table (@from_tables) {
    my $from_query = qq{SHOW COLUMNS FROM $table};
    my @from_cols = @{$from_dbh->selectcol_arrayref( $from_query )};

    my $to_query = qq{SHOW COLUMNS FROM $table};
    my @to_cols = @{$to_dbh->selectcol_arrayref( $to_query )};

    unless ( lists_equal( \@from_cols, \@to_cols ) ) {
        say "Database table $table columns do not match";
	say "From columns: " . Data::Dumper::Dumper( \@from_cols );
	say "To columns: " . Data::Dumper::Dumper( \@to_cols );
        $from_dbh->rollback();
        $from_dbh->disconnect();
        $to_dbh->rollback();
        $to_dbh->disconnect();
	exit(1);
    } else {
        say "Columns for table $table match!" if $opt->verbose > 1;
    }
}
say "Columns for all tables match!" if $opt->verbose;

eval {
    $to_dbh->commit();
    $from_dbh->rollback();
};

if ($@) {
    say "Error, merge aborted: $@";
    $from_dbh->rollback();
    $from_dbh->disconnect();
    $to_dbh->rollback();
    $to_dbh->disconnect();
}

sub lists_equal {
    my ( $first, $second ) = @_;

    my @a = sort @$first;
    my @b = sort @$second;

    return 0 unless scalar @a == scalar @b;

    for ( my $i = 0; $i < scalar @a; $i++ ) {
        return 0 if $a[$i] ne $b[$i];
    }

    return 1;
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
