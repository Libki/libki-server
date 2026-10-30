package Libki::Controller::Administration::API::PrintJob;
use Moose;
use namespace::autoclean;

use File::Temp qw( tempfile );
use HTTP::Request::Common;
use JSON qw( to_json from_json );
use MIME::Base64;
use Storable qw( thaw );
use YAML::XS;

use Libki::Utils::Printing;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::Print - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 cancel

Endpoint to set a print job status to Canceled.

=cut

sub cancel : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $id = $c->request->params->{id};

    my $print_job = $c->model('DB::PrintJob')->find( { id => $id, instance => $instance } );

    if ($print_job) {
        my $now = $c->now();

        my $success = $print_job->update(
            {
                status     => 'Canceled',
                updated_on => $now,
            }
        ) ? 1 : 0;
        $c->stash( success => $success );
    }
    else {
        $c->stash( success => 0, error => 'PRINT_JOB_NOT_FOUND' );
    }

    $c->forward( $c->view('JSON') );
}

=head2 cups_setup

Initializes the Net::CUPS module with the values from the configuration.

=cut

sub cups_setup : Private : Args(0) {
    my ( $self, $c ) = @_;

    require Net::CUPS;
    my $instance = $c->instance;

    my $printers_conf = $c->get_printer_configuration;

    my $cups_server = $printers_conf->{cups}->{server};
    my $cups_username = $printers_conf->{cups}->{username};


    my $cups = Net::CUPS->new();
    $cups->setServer($cups_server);
    $cups->setUsername($cups_username);
    return $cups;
}

=head2 cups_create_print_file

Stores the print data on a temporary file and returns the filename

=cut

sub cups_create_print_file : Private : Args(0) {
    my ( $self, $c, $print_data ) = @_;
    my $instance = $c->instance;

    my $tmp_fh = new File::Temp ( UNLINK => 0 );
    binmode ($tmp_fh);
    $tmp_fh->write($print_data);
    $tmp_fh->close();
    return $tmp_fh;

}

=head2 preview

Return a side-effect-free staff review of a held print job.

=cut

sub preview : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles(qw/admin/);

    my $data = Libki::Utils::Printing::build_release_preview(
        $c,
        { print_job_id => $c->request->params->{id}, copies => $c->request->params->{copies} }
    );
    # Return only the quote; never serialize unrelated settings from the stash.
    $c->response->content_type('application/json; charset=utf-8');
    $c->response->header('Cache-Control' => 'no-store');
    $c->response->body(to_json($data));
}

=head2 release

Sends the given print job to the actual print management backend.

=cut

sub release : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles(qw/admin/);

    unless ( $c->request->method eq 'POST' ) {
        $c->response->status(405);
        $c->stash( success => 0, error => 'METHOD_NOT_ALLOWED' );
        $c->forward( $c->view('JSON') );
        return;
    }

    unless (
        ( $c->request->headers->header('X-Requested-With') || q{} )
        eq 'XMLHttpRequest'
    ) {
        $c->response->status(400);
        $c->stash( success => 0, error => 'INVALID_RELEASE_REQUEST' );
        $c->forward( $c->view('JSON') );
        return;
    }

    my $printers = $c->get_printer_configuration;
    unless ( ( $printers->{staff_print_release} || 'disabled' ) eq 'enabled' ) {
        $c->stash(
            success => 0,
            error   => 'STAFF_PRINT_RELEASE_DISABLED',
        );
        $c->forward( $c->view('JSON') );
        return;
    }

    unless ( ( $c->request->params->{cash_received} || q{} ) eq '1' ) {
        $c->stash(
            success => 0,
            error   => 'CASH_PAYMENT_NOT_CONFIRMED',
        );
        $c->forward( $c->view('JSON') );
        return;
    }

    my $id = $c->request->params->{id};

    my $data = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id    => $id,
            payment_method  => 'cash',
            expected_amount => $c->request->params->{expected_amount},
            copies => $c->request->params->{copies},
            request_id => $c->request->params->{request_id},
        }
    );
    $c->stash( $data );

    $c->forward( $c->view('JSON') );
}

=head2 reprint

Create a new audited held job from a completed CUPS job and immediately send
that new job through the normal cash-confirmed production release path.

=cut

sub reprint : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->assert_user_roles(qw/admin/);

    unless ( $c->request->method eq 'POST' ) {
        $c->response->status(405);
        $c->stash( success => 0, error => 'METHOD_NOT_ALLOWED' );
        $c->forward( $c->view('JSON') );
        return;
    }

    unless (
        ( $c->request->headers->header('X-Requested-With') || q{} )
        eq 'XMLHttpRequest'
    ) {
        $c->response->status(400);
        $c->stash( success => 0, error => 'INVALID_REPRINT_REQUEST' );
        $c->forward( $c->view('JSON') );
        return;
    }

    unless ( ( $c->request->params->{cash_received} || q{} ) eq '1' ) {
        $c->stash( success => 0, error => 'CASH_PAYMENT_NOT_CONFIRMED' );
        $c->forward( $c->view('JSON') );
        return;
    }

    my $created = Libki::Utils::Printing::create_reprint_job(
        $c,
        {
            print_job_id    => $c->request->params->{id},
            expected_amount => $c->request->params->{expected_amount},
            copies => $c->request->params->{copies},
            request_id => $c->request->params->{request_id},
        }
    );
    unless ( $created->{success} ) {
        $c->stash($created);
        $c->forward( $c->view('JSON') );
        return;
    }

    my $existing = $c->model('DB::PrintJob')->find({ id => $created->{reprint_job_id}, instance => $c->instance });
    if ($existing && ($existing->status eq 'Done' || $existing->status eq 'InProgress')) {
        $c->stash(success => 1, reprint_job_id => $existing->id, message => 'This reprint request was already accepted.');
        $c->forward($c->view('JSON'));
        return;
    }
    my $released = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id    => $created->{reprint_job_id},
            payment_method  => 'cash',
            expected_amount => $created->{amount_due},
        }
    );
    $released->{source_print_job_id} = $created->{source_print_job_id};
    $released->{reprint_job_id}      = $created->{reprint_job_id};
    $c->stash($released);
    $c->forward( $c->view('JSON') );
}

=head2 update

Updates the status of a print job from the backend print management system.
The JSON returned by the status request is stored in print_jobs.data.

=cut

sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $print_job_id = $c->request->params->{id};
    unless ( defined $print_job_id && $print_job_id =~ m{\A\d+\z} ) {
        $c->response->status(400);
        $c->stash(
            success => 0,
            error   => 'INVALID_PRINT_JOB_ID',
        );
        delete $c->stash->{Settings};
        $c->forward( $c->view('JSON') );
        return;
    }

    my $print_job = $c->model('DB::PrintJob')->find($print_job_id);
    if ($print_job) {
        if ($print_job->type eq 'cups') {

            my $cups = $self->cups_setup($c);

            if ( $print_job->status ne 'completed' ) {

                my $printers = $c->get_printer_configuration;
                my $printer  = $printers->{printers}->{ $print_job->printer };
                if ($printer) {

                    my $cups_printer_name = $printer->{name};
                    my $cups_printer = $cups->getDestination($cups_printer_name);
                    if ($cups_printer) {

                        my $cups_printjob_id = $print_job->data->{id};
                        if ($cups_printjob_id) {
                            my $cups_print_job_data = $cups_printer->getJob($cups_printjob_id);
                            if ($cups_print_job_data) {
                                my $cups_print_job_state = $cups_print_job_data->{state_text};
                                my $now = $c->now();
                                $print_job->update(
                                    {
                                        data       => $cups_print_job_data,
                                        status     => $cups_print_job_state,
                                        updated_on => $now,
                                    }
                                );
                                $c->stash( success => 1 );
                            }
                            else {
                                $c->stash( success => 0, error => 'Error getting CUPS printjob data', id => $cups_printjob_id );
                            }
                        }
                        else {
                            $c->stash( success => 0, error => 'CUPS printjob not found', id => $cups_printjob_id );
                        }
                    }
                    else {
                        $c->stash( success => 0, error => 'Printer Not Found on CUPS server', id => $print_job->printer );
                    }
                }
                else {
                    $c->stash( success => 0, error => 'Printer Not Found', id => $print_job->printer );
                }
            }
            elsif ( $print_job ) {
                $c->stash( success => 1 );
            }
        }
        elsif ($print_job->type eq 'PrintManager') {
            $c->stash( success => 1 );
        }
    }
    else {
        $c->stash->{success} = 0;
        $c->stash->{error}   = 'Print Job Not Found';
    }

    delete $c->stash->{Settings};
    $c->forward( $c->view('JSON') );
}

=head2 view

Returns the PDF of a given print job.
If the param 'type' is set to 'view', the content
disposition will be so so the PDF loads in a web browser.

=cut

sub view : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $CanAdminsViewPrintFiles = $c->setting('CanAdminsViewPrintFiles');
    unless ( $CanAdminsViewPrintFiles eq 'Y' ) {
        $c->response->body('You are not authorised to access this file.');
        $c->response->status(403);
        return;
    }

    my $id = $c->request->params->{id};
    my $type = $c->request->params->{type} || 'view';

    my $print_job = $c->model('DB::PrintJob')->find($id);

    if ($print_job) {
        my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );
        if ($print_file) {
            my $filename = $print_file->filename;

            $c->response->body( $print_file->data );

            if ( $type eq 'view' ) {
                $c->response->content_type('application/pdf');
                $c->response->header( 'Content-Disposition', "inline; filename=\"$filename\"" );
            } else {
                $c->response->content_type('application/octet-stream');
                $c->response->header( 'attachment', $filename );
            }
        }
        else {
            $c->stash( success => 0, error => 'PRINT_FILE_NOT_FOUND' );
            $c->forward( $c->view('JSON') );
        }
    }
    else {
        $c->stash( success => 0, error => 'PRINT_JOB_NOT_FOUND' );
        $c->forward( $c->view('JSON') );
    }
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

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

__PACKAGE__->meta->make_immutable;

1;
