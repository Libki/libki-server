#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;

use DBI;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'from-database|fd=s', "Database to move data from, required"     , { required => 1 } ],
    [ 'from-hostname|fh=s', "Database host to move data from, required", { required => 1 } ],
    [ 'from-port|fp=s'    , "Database port to move data from, required", { required => 1 } ],
    [ 'from-user|fu=s'    , "Database user to move data from, required", { required => 1 } ],
    [ 'from-password|fp=s', "Database user to move data from, required", { required => 1 } ],
    [],
    [ 'to-database|fd=s', "Database to move data to, required"     , { required => 1 } ],
    [ 'to-hostname|fh=s', "Database host to move data to, required", { required => 1 } ],
    [ 'to-port|fp=s'    , "Database port to move data to, required", { required => 1 } ],
    [ 'to-user|fu=s'    , "Database user to move data to, required", { required => 1 } ],
    [ 'to-password|fp=s', "Database user to move data to, required", { required => 1 } ],
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
my @from_tables = $from_dbh->tables;
my @to_tables = $to_dbh->tables;

die "Database tables do not match" unless @from_tables ~~ @to_tables;

# Verify each table pair in the databases have matching columns
foreach my $table (@from_tables) {
    my $from_sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0");
    $from_sth->execute;
    my @from_cols = @{ $from_sth->{NAME_lc} };
    $from_sth->finish;

    my $to_sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0");
    $to_sth->execute;
    my @to_cols = @{ $to_sth->{NAME_lc} };
    $to_sth->finish;

    die "Database table $table columns do not match" unless @from_cols ~~ @to_cols;
}

eval {
}

if ($@) {
    say "Error, merge aborted: $@";
    $dbh_from->rollback();
    $dbh_to->rollback();
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
