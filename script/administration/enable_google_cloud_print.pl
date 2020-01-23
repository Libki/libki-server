#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;
use MIME::Base64;
use Net::Google::DataAPI::Auth::OAuth2;
use Storable qw(freeze);
use Term::Prompt;

use Libki;

my ( $opt, $usage ) = describe_options(
    '%c %o',
    [ 'instance|i=s', "the instance for the user to exist on", { default => q{} } ],
    [],
    [ 'verbose|v', "print extra stuff" ],
);
my $c = Libki->new();

my $instance = $opt->instance;

my $printers_conf = $c->get_printer_configuration( { instance => $instance } );

my $client_secret = $printers_conf->{google_cloud_print}->{client_secret};
my $client_id = $printers_conf->{google_cloud_print}->{client_id};

my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
    client_id => $client_id,
    client_secret => $client_secret,
    scope => ['https://www.googleapis.com/auth/cloudprint'],
);

my $url = $oauth2->authorize_url();

say "Please visit this URL in a web browser: $url";

my $code = prompt('x', 'Paste in code:', '', '');

my $token = $oauth2->get_access_token($code) or die 'Unable to get access token';
my $session = $token->session_freeze;

my $frozen = freeze($session);
my $encoded = encode_base64( $frozen );
$c->model('DB::Setting')->update_or_create(
    {
	instance => $instance,
	name     => 'google_cloud_print_session',
	value    => $encoded,
    }
);

say "Session stored.";

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
