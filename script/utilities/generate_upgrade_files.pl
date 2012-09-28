#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use DBIx::Class::DeploymentHandler;
use SQL::Translator;
use Config::JFDI;

use Libki::Schema::DB;

my $config = Config::JFDI->new( file => 'libki_local.conf', no_06_warning => 1 );
my $config_hash  = $config->get();
my $connect_info = $config_hash->{'Model::DB'}->{'connect_info'};

my $schema = 'Libki::Schema::DB';

my $version = eval "use $schema; $schema->VERSION" or die $@;

print "Processing version $version of $schema...\n";

my $s = $schema->connect($connect_info)
  || die("Couldn't Connect to DB");

my $dh = DBIx::Class::DeploymentHandler->new( {
        schema              => $s,
        script_directory => "$FindBin::Bin/../../sql",
        databases           => [qw/ SQLite PostgreSQL MySQL /],
        sql_translator_args => { add_drop_table => 0, },
    } );

print "Generating deployment script...\n";
$dh->prepare_install;

if ( $version > 1 ) {
    print "Generating upgrade script...\n";
    $dh->prepare_upgrade( {
            from_version => $version - 1,
            to_version   => $version,
            version_set  => [ $version - 1, $version ],
        } );

    print "Generating downgrade script...\n";
    $dh->prepare_downgrade( {
            from_version => $version,
            to_version   => $version - 1,
            version_set  => [ $version, $version - 1 ],
        } );
}

print "Done\n";
