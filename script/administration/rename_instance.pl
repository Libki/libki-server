#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;

use Libki;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'from|f=s', "the existing instance name, required", { required => 1 } ],
    [ 'to|t=s', "the new instance name, required", { required => 1 } ],
    [],
    [ 'verbose|v+', "print extra stuff" ],
);

print( $usage->text ), exit unless defined $opt->to;
print( $usage->text ), exit unless defined $opt->from;

my $c = Libki->new();
my $schema = $c->model('DB::User')->result_source->schema
  || die("Couldn't Connect to DB");
my $dbh = $schema->storage->dbh;

my $from = $opt->from || q{};
my $to = $opt->to;

my @tables = qw{
    client_age_limits
    clients
    closing_hours
    jobs
    locations
    messages
    print_files
    print_jobs
    reservations
    sessions
    settings
    statistics
    users
};

foreach my $table ( @tables ) {
    my $query = qq{UPDATE $table SET instance = ? WHERE instance = ?};
    my $sth = $dbh->prepare( $query );
    $sth->execute( $to, $from );
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
