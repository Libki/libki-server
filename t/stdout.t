#!/usr/bin/env perl

use Modern::Perl;

use FindBin qw($Bin);

use Test::More tests => 1;

my $output = qx{$Bin/../script/administration/create_user.pl 2>&1};
ok( $output, "Running create_user gave some form of output" );
