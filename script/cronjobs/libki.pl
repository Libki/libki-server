#!/usr/bin/perl

use strict;
use warnings;

use Config::JFDI;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki::Schema::DB;

my $config = Config::JFDI->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
    no_06_warning => 1
);
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

## Decrement time for logged in users.
my $session_rs = $schema->resultset('Session');
while ( my $session = $session_rs->next() ) {
    $session->user->decrease_minutes(1);
    $session->user->update();
}

## Delete clients that haven't updated recently
my $post_crash_timeout = $schema->resultset('Setting')->find('PostCrashTimeout')->value;
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime(time - ( $post_crash_timeout * 60 ) );
my $timestamp = sprintf(
    "%04d-%02d-%02d %02d:%02d:%02d",
    $year + 1900,
    $mon + 1, $mday, $hour, $min, $sec
);
$schema->resultset('Client')->search({ last_registered => { '<', $timestamp } })->delete();
