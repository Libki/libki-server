#!/usr/bin/perl

use strict;
use warnings;

use Config::JFDI;
use Getopt::Long::Descriptive;

use Libki::Schema::DB;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'username|u=s', "the username for this user, required" ],
    [ 'password|p=s', "the password for this user" ],
    [ 'minutes|m=s',  "number of minutes for this user" ],
    [],
    [ 'verbose|v', "print extra stuff" ],
);

print( $usage->text ), exit unless ( $opt->username );

my $config =
  Config::JFDI->new( file => 'libki_local.conf', no_06_warning => 1 );
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = Libki::Schema::DB->connect($connect_info)
  || die("Couldn't Connect to DB");

my $user_rs = $schema->resultset('User');

$user_rs->create(
    {
        username        => $opt->username,
        password        => $opt->password,
        minutes         => $opt->minutes,
        status          => 'enabled',
        is_troublemaker => 'No',
    }
);
