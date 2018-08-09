#!/usr/bin/env perl

use Modern::Perl;

use Test::More;

use Catalyst::Test 'Libki';

use Libki;

$ENV{LIBKI_INSTANCE} = "TEST";

my $c = Libki->new();
my $schema = $c->model('DB::User')->result_source->schema || die("Couldn't Connect to DB");
my $dbh = $schema->storage->dbh;
$schema->storage->txn_begin;

ok( request('/')->is_success, 'Request should succeed' );

done_testing();
