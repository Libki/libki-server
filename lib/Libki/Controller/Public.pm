package Libki::Controller::Public;

use Moose;
use namespace::autoclean;

use Libki::Utils::Printing;

use LWP::UserAgent;
use LWP::Protocol::https;
use HTTP::Request;
use HTTP::Request::Common;
use Data::Dumper;

{
    package Libki::PDFAutoConvert;
    sub filename      { shift->{_filename} }
    sub type          { shift->{_type} }
    sub decoded_slurp { shift->{_content} }
}

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Public - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path {
    my ( $self, $c, $tab ) = @_;

    my $instance = $c->instance;

    $tab ||= 'clients';
    $tab = 'clients' if $tab ne 'printing';

    $c->stash(
        tab => $tab,
        CustomJsPublic => $c->setting('CustomJsPublic'),
    );
}

=head2 upload_print_file

=cut

sub upload_print_file :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->model('DB::User')->find({ instance => $c->instance, username => $c->user->username });

    my $print_file = $c->req->upload('print_file');
    my $printer_id  = $c->req->params->{printer_id};

    my $mime = $print_file->mimetype;
    my ($ext) = $print_file->filename =~ /\.([^.]+)$/;
    $ext = lc $ext if defined $ext;
    my $nonpdf_supported = $c->get_printer_configuration->{'pdf_conversion_service'}->{'supported_extensions'};

    if ( $mime eq "application/pdf" && $ext eq "pdf" ) {
        Libki::Utils::Printing::create_print_job_and_file( $c, {
            client_name => Libki::Utils::Printing::PRINT_FROM_WEB,
            copies      => 1,
            print_file  => $print_file,
            printer_id  => $printer_id,
            user        => $user,
            username    => $user->username,
        } );

        $c->response->redirect( $c->uri_for('/public/printing') );
    } elsif ($nonpdf_supported && grep { $_ eq $ext } @$nonpdf_supported ) {
        my $ua = LWP::UserAgent->new(timeout => 600);
        my $service_url = $c->get_printer_configuration->{'pdf_conversion_service'}->{'service_url'};

        my $request = HTTP::Request::Common::POST(
            $service_url,
            Content_Type => 'form-data',
            Content      => [
                file => [ $print_file->tempname, $print_file->filename, $print_file->type ]
            ]
        );
        my $res = $ua->request($request);
        if ($res->is_success) {
            my $pdf_data = $res->decoded_content(charset => 'none');
            my $converted_upload = bless {
                _filename => $print_file->filename . ".pdf",
                _type     => 'application/pdf',
                _content  => $pdf_data,
            }, 'Libki::PDFAutoConvert';
            Libki::Utils::Printing::create_print_job_and_file( $c, {
                client_name => Libki::Utils::Printing::PRINT_FROM_WEB,
                copies      => 1,
                print_file  => $converted_upload,
                printer_id  => $printer_id,
                user        => $user,
                username    => $user->username,
            } );
            $c->response->redirect( $c->uri_for( '/public/printing', undef, { success => 'PDF_CONV_SUCCESS' } ));
        } else {
            $c->response->redirect( $c->uri_for( '/public/printing', undef, { error => 'PDF_CONV_ERROR' } ));
            # print Dumper $res;
        }
    } else {
        $c->response->redirect( $c->uri_for( '/public/printing', undef, { error => 'INVALID_FILETYPE' } ));
    }

}

=head2 auto
    
Check if there is an authorized user and, if not, forward to login page
    
=cut

# Note that 'auto' runs after 'begin' but before your actions and that
# 'auto's "chain" (all from application path to most specific class are run)
# See the 'Actions' section of 'Catalyst::Manual::Intro' for more info.
sub auto : Private {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my @locations = $c->model('DB::Client')->search(
        {
            instance => $instance,
        },
        {
            columns  => [qw/location/],
            distinct => 1
        }
    )->get_column('location')->all();

    $c->stash( 
        interface => 'public',
        locations => \@locations,
    );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

This file is part of Libki.

Libki is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as 
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

Libki is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Libki.  If not, see <http://www.gnu.org/licenses/>.

=cut

__PACKAGE__->meta->make_immutable;

1;
