#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;

use Libki;
use Libki::SIP qw( authenticate_via_sip );

use Data::Dumper;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'instance|i=s', "the instance for the user to exist on", { default => q{} } ],
    [ 'username|u=s', "the username for this user, required", { required => 1 } ],
    [ 'password|p=s', "the password for this user" ],
    [],
    [ 'verbose|v', "print extra stuff" ],
);

print( $usage->text ), exit unless ( $opt->username );

$ENV{LIBKI_INSTANCE} = $opt->instance || q{};

my $c = Libki->new();
my $schema = $c->model('DB::User')->result_source->schema
  || die("Couldn't Connect to DB");

my $user_rs = $schema->resultset('User');

my $user = $user_rs->search( { instance => $opt->instance, username => $opt->username } )->next();

my $r = Libki::SIP::authenticate_via_sip( $c, $user, $opt->username, $opt->password, 1 );

say "Libki::SIP::authenticate_via_sip: ";
say "SUCCESS: $r->{success}";
say "ERROR MESSAGE: $r->{error}" unless $r->{success};
say "SIP FIELDS: " . Data::Dumper::Dumper( $r->{sip_fields} );

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
