package Libki::Controller::Administration::API::PrintJob;
use Moose;
use namespace::autoclean;

use HTTP::Request::Common;
use JSON qw( to_json from_json );
use MIME::Base64;
use Net::CUPS;
use Storable qw( thaw );
use YAML::XS;
use File::Temp qw( tempfile );

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

=head2 release

Sends the given print job to the actual print management backend.

=cut

sub release : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $id = $c->request->params->{id};

    my $print_job = $c->model('DB::PrintJob')->find( { id => $id, instance => $instance } );


    if ($print_job) {
        # CUPS print support
        if ($print_job->type eq 'cups') {
            my $log = $c->log();
            my $cups = $self->cups_setup($c);

            my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );
            if ($print_file) {

                my $printers = $c->get_printer_configuration;
                my $printer  = $printers->{printers}->{ $print_job->printer };

                if ($printer) {

                    my $filename = $print_file->filename;
                    my $content  = $print_file->data;

                    my $cups_printer_name = $printer->{name};
                    $log->debug("CUPS Printer name: " . $cups_printer_name);
                    my $cups_printer = $cups->getDestination($cups_printer_name);
                    if ($cups_printer) {
                        # In order to print to CUPS, the data must be on a file
                        # Create a temporary file to print
                        my $cups_print_filename = $self->cups_create_print_file($c, $content);
                        $log->debug("Created temp file for CUPS printing: " . $cups_print_filename);
                        # The job title is the original print file name
                        my $cups_print_job_id = $cups_printer->printFile($cups_print_filename, $filename);
                        unlink ($cups_print_filename);
                        if ($cups_print_job_id) {

                            my $cups_print_job_data = $cups_printer->getJob($cups_print_job_id);
                            my $cups_print_job_state = $cups_print_job_data->{state_text};
                            my $now = $c->now();
                            $print_job->update(
                                {
                                    data       => $cups_print_job_data,
                                    status     => $cups_print_job_state,
                                    updated_on => $now,
                                }
                            );

                            $c->stash( success => 1, message => 'Ok' );

                        }
                        else {
                            $c->stash( success => 0, error => 'Error printing on printer', id => $print_job->printer );
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
            else {
                $c->stash(
                    success => 0,
                    error   => 'Print File Not Found',
                    id      => $print_job->print_file_id
                );
            }
        }
    }
    else {
        $c->stash( success => 0, error => 'Print Job Not Found', id => $id );
    };

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
                                $c->stash->{success} = 1;
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
                $c->stash->{success} = 1;
            }
        };

	if ( $print_job->type eq 'PrintManager' ) {
            $c->stash->{success} = 1;
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
                $c->response->header( 'Content-Disposition', "inline; filename=$filename" );
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
