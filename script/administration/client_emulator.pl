#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;
use LWP::UserAgent;
use LWP::Simple;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'scheme|s=s', 'the scheme to use ( http or https )', { default => 'http' } ],
    [ 'host|h=s',   'the host server address',             { default => '127.0.0.1' } ],
    [ 'port|p=s',   'the host server port',                { default => '3000' } ],
    [
        'action|a=s',
        'action to take ( options: register_client, client_login, client_logout, print )',
        { default => 'register_client' }
    ],
    [],
    [ 'name|node-name|n=s', 'name for the mocked client',          { default => 'test_client' } ],
    [ 'type|t=s',           'the client type',                     { default => '' } ],
    [ 'location|loc|l=s',   'location code for the mocked client', { default => 'TEST' } ],
    [],
    [ 'username|un|u=s', 'username for action=client_login/out' ],
    [ 'password|pw=s',   'password for action=client_login/out' ],
    [],
    [ 'print=s', 'Send file as print job for node' ],
    [],
    [ 'verbose|v+', 'print extra stuff', { default => 0 } ],
);

my $base_url = $opt->scheme . '://' . $opt->host . ':' . $opt->port;
say "BASE URL: $base_url" if $opt->verbose;
my $api_url = "$base_url/api/client/v1_0";
say "API URL: $api_url" if $opt->verbose > 1;

my $ua = LWP::UserAgent->new();

if ( $opt->action eq 'register_client' || $opt->action eq 'client_login' ) {
    say 'ACTION: register_client' if $opt->verbose;

    die "MISSING PARAMETER: name"     unless $opt->name;
    die "MISSING PARAMETER: location" unless $opt->location;

    my $response = $ua->post(
        $api_url,
        Content => [
            action    => 'register_node',
            node_name => $opt->name,
            location  => $opt->location,
        ],
    );

    if ( $response->is_success ) {
        say "REGISTER succeeded!";
    }
    else {
        say "REGISTER failed!";
        say $response->status_line . " - " . $response->message;
    }

}
if ( $opt->action eq 'client_login' ) {
    say 'ACTION: client_login' if $opt->verbose;

    die "MISSING PARAMETER: name"     unless $opt->name;
    die "MISSING PARAMETER: location" unless $opt->location;
    die "MISSING PARAMETER: username" unless $opt->username;
    die "MISSING PARAMETER: password" unless $opt->password;

    my $response = $ua->post(
        $api_url,
        Content => [
            action   => 'login',
            node     => $opt->name,
            location => $opt->location,
            username => $opt->username,
            password => $opt->password,
            type     => $opt->type,
        ],
    );

    if ( $response->is_success ) {
        say "LOGIN Response: " . $response->decoded_content;
    }
    else {
        say "LOGIN failed!";
        say $response->status_line . " - " . $response->message;
    }
}
if ( $opt->action eq 'client_logout' ) {
    say 'ACTION: client_logout' if $opt->verbose;

    die "MISSING PARAMETER: name"     unless $opt->name;
    die "MISSING PARAMETER: username" unless $opt->username;
    die "MISSING PARAMETER: password" unless $opt->password;

    my $response = $ua->post(
        $api_url,
        Content => [
            action   => 'logout',
            node     => $opt->name,
            location => $opt->location,
            username => $opt->username,
            password => $opt->password,
            type     => $opt->type,
        ],
    );

    if ( $response->is_success ) {
        say "LOGOUT Response: " . $response->decoded_content;
    }
    else {
        say "LOGOUT failed!";
        say $response->status_line . " - " . $response->message;
    }
}
if ( $opt->action eq 'print' ) {
    my $print_url = "$api_url/print";
    say "ACTION: print" if $opt->verbose;

    my $response = $ua->post(
        $print_url,
        Content_Type => 'multipart/form-data',
        Content      => [
            node       => $opt->name,
            print_file => [ $opt->print ],
        ]
    );
    print $response->error_as_HTML . "\n" if $response->is_error;
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
