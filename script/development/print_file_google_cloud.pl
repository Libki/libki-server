#!/usr/bin/perl

use Modern::Perl;

use Config::JFDI;
use Term::Prompt;
use Storable qw(thaw);
use JSON;
use Getopt::Long::Descriptive;

use HTTP::Request::Common;
use Net::OAuth2::AccessToken;
use Net::Google::DataAPI::Auth::OAuth2;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Libki;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'instance|i=s', "the instance to use",     { default  => q{} } ],
    [ 'printer|p=s',  "the printer to print to", { required => 1 } ],
    [
        'file_id|file-id|f=s',
        "the id of the print_file in the database",
        { required => 1 }
    ],
    [],
    [ 'verbose|v', "print extra stuff" ],
);

my $config = Config::JFDI->new(
    file          => "$FindBin::Bin/../../libki_local.conf",
    no_06_warning => 1
);

my $c = Libki->new(
    { database_file => $config->{'Model::DB'}{args}{database_file} } );

my $instance      = $opt->instance;
my $printer_id    = $opt->printer;
my $print_file_id = $opt->file_id;

my $print_file = $c->model('DB::PrintFile')->find($print_file_id);
unless ($print_file) {
    say "Unable to find print file with id $print_file_id";
    exit();
}

my $conf          = $c->config->{instances}->{$instance} || $c->config;
my $printers_conf = $conf->{printers};
my $printers      = $printers_conf->{printer};

my $printer = $printers->{$printer_id};
unless ($printer) {
    say "Unable to find printer '$printer_id' in Libki config";
    exit();
}

if ( $printer->{type} = 'google_cloud_printer' ) {

    my $client_secret = $printers_conf->{google_cloud_print}->{client_secret};
    my $client_id     = $printers_conf->{google_cloud_print}->{client_id};

    my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
        client_id     => $client_id,
        client_secret => $client_secret,
        scope         => ['https://www.googleapis.com/auth/cloudprint'],
    );

    my $stored_token = $c->model('DB::Setting')->single(
        {
            instance => $instance,
            name     => 'google_cloud_print_session',
        }
    );

    my $saved_session = thaw( $stored_token->value );

    my $token = Net::OAuth2::AccessToken->session_thaw(
        $saved_session,
        auto_refresh => 1,
        profile      => $oauth2->oauth2_webserver,
    );
    $oauth2->access_token($token);

    my $oa = $oauth2->oauth2_client;

    my $r = $token->get('https://www.google.com/cloudprint/search');

    my $resp = $token->profile->request_auth( $token,
        GET => 'https://www.google.com/cloudprint/search' );

    my $filename = $print_file->filename;
    my $content  = $print_file->data;

    my $ticket = { "version" => "1.0", "print" => {}, };

    my $ticket_conf = $printer->{ticket};
    foreach my $key ( keys %$ticket_conf ) {
        my $data = from_json( $ticket_conf->{ $key } );
        $ticket->{print}->{ $key } = $data;
    }

    my $ticket_json = to_json( $ticket );

    my $request = POST 'https://www.google.com/cloudprint/submit',
      Content_Type => 'form-data',
      Content      => [
        printerid => $printer->{google_cloud_id},
        content   => [ undef, $filename, Content => $content ],
        title     => $filename,
        ticket    => $ticket_json,
      ];

    $resp = $token->profile->request_auth( $token, $request );

    print Data::Dumper::Dumper($resp);

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
