#!/usr/bin/perl

use strict;
use warnings;

use Config::JFDI;

use Libki::Model::DB;
use Libki::Schema::DB;

my $config = Config::JFDI->new( file => '/home/libki/Libki/libki_local.conf' );
my $config_hash  = $config->get;
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my @users = $schema->resultset('User')->all;

foreach my $user (@users) {
    print "Working on " . $user->username() . "\n";
    print "password hash was: " . $user->password() . "\n";

    $user->password('letmein');
    $user->update;

    print "password hash is now: " . $user->password() . "\n";

}
