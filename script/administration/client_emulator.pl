#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;
use LWP::UserAgent;
use LWP::Simple;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [
        'scheme|s=s',
        'the scheme to use ( http or https )',
        { default => 'http' }
    ],
    [ 'host|h=s', 'the host server address', { required => 1 } ],
    [ 'port|p=s', 'the host server port',    { default  => 80 } ],
    [
        'action|a=s',
        'action to take ( options: register_node )',
        { default => 'register_node' }
    ],
    [],
    [
        'name|node-name|n=s',
        'name for the mocked client',
        { default => 'test_client' }
    ],
    [
        'location|loc|l=s',
        'location code for the mocked client',
        { default => 'TEST' }
    ],
    [ 'print=s', 'Send file as print job for node' ],
    [],
    [ 'verbose|v+', 'print extra stuff', { default => 0 } ],
);

my $base_url = $opt->scheme . '://' . $opt->host . ':' . $opt->port;
say "BASE URL: $base_url" if $opt->verbose;
my $api_url = "$base_url/api/client/v1_0";
say "API URL: $api_url" if $opt->verbose > 1;
my $url = $api_url . '?action=' . $opt->action;

if ( $opt->action eq 'register_node' ) {
    say 'ACTION: register_node' if $opt->verbose;
    $url .= '&node_name=' . $opt->name;
    $url .= '&location=' . $opt->location;

    say "GET URL: $url" if $opt->verbose;

    my $res = get($url);

    say $res ? 'SUCCESS' : 'FAILED' if $opt->verbose;

    say "RESULTS: $res" if $opt->verbose > 2;
}
elsif ( $opt->action eq 'print' ) {
    my $print_url = "$api_url/print";
    say "ACTION: print" if $opt->verbose;
    say "   URL: $print_url" if $opt->verbose > 1;

    my $ua = LWP::UserAgent->new();
    my $response   = $ua->post( $print_url,
      Content_Type => 'multipart/form-data',
      Content      => [
        node       => $opt->name,
        print_file => [ $opt->print ],
      ] );
    print $response->error_as_HTML . "\n" if $response->is_error;
}
else {
    say 'Unknown action "' . $opt->action . '" requested.';
    say $usage;
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
