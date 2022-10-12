#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;

use Libki;
use Libki::Users;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'file|f=s', "path to the users file, required", { required => 1 } ],
    [
        'delimeter|d=s',
        "Delimeter to use, 'comma' or 'tab'",
        { default => 'tab' }
    ],
    [ 'start|s=s',   "start at this line of the file",      { default => 0 } ],
    [ 'overwrite|o', "Update existing user if match found", { default => 0 } ],
    [ 'username-column|uc=s', "username column index", { required => 1 } ],
    [ 'password-column|pc=s', "password column index", { required => 1 } ],
    [
        'instance|i=s',
        "the instance for the user to exist on",
        { default => q{} }
    ],
    [],
    [ 'verbose|v+', "print extra stuff" ],
    [
        'test|t',
        "test mode, does not commit changes to database",
        { implies => { 'verbose' => 1 } }
    ],
    [],
    [ 'help', "print usage message and exit", { shortcircuit => 1 } ],

);

print( $usage->text ), exit if $opt->help;
print( $usage->text ), exit unless $opt->file;
print( $usage->text ), exit
  unless ( $opt->delimeter eq 'comma' || $opt->delimeter eq 'tab' );

$ENV{LIBKI_INSTANCE} = $opt->instance;

my $c      = Libki->new();
my $schema = $c->schema;

my $r = Libki::Users::import_users(
    {
        context         => $c,
        file            => $opt->file,
        delimeter       => $opt->delimeter,
        start           => $opt->start,
        username_column => $opt->username_column,
        password_column => $opt->password_column,
        update          => $opt->overwrite,
        verbose         => $opt->verbose,
        test            => $opt->test,
    }
);

if ( $opt->verbose ) {
    say "CREATED: " . scalar @{ $r->{created} };
    say "UPDATED: " . scalar @{ $r->{updated} };
    say "SKIPPED: " . scalar @{ $r->{skipped} };
    say "UNPARSABLE: " . scalar @{ $r->{unparsable} };
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
