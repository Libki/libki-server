package Libki::Utils::Printing;

use Modern::Perl;

use PDF::API2;

use constant PRINT_FROM_WEB => '__PRINT_FROM_WEB__';

use constant PRINT_STATUS_PENDING => 'Pending';    # Waiting for PrintManager/CUPS to accept the job
use constant PRINT_STATUS_PROCESSING => 'Processing';   # Needs to be evaluated for sufficient funds
use constant PRINT_STATUS_INSUFFICIENT_FUNDS => 'Insufficient Funds'; # User doesn't have funds to cover printing
use constant PRINT_STATUS_IN_PROGRESS => 'InProgress'; # Print job is being sent to printer
use constant PRINT_STATUS_DONE => 'Done'; # Printer has accepted the print job
=head2 create_print_job_and_file

Helper function to create a print_job and print_file entry from the given PDF and data.

Printing may be initiated by a Libki Client via the API,
or by uploading a file to print via the public self-service web interface

=cut

sub create_print_job_and_file {
    my ( $c, $params ) = @_;

    my $client      = $params->{client};         # DB::Client object, optional
    my $client_name = $params->{client_name};    # Client name file was printed from, if any
    my $copies      = $params->{copies};         # How many copies of this file are to be printed
    my $print_file  = $params->{print_file};     # Catalyst::Request::Upload object
    my $printer_id  = $params->{printer_id};     # Printer id from printer configuration setting
    my $user        = $params->{user};           # DB::User object, optional
    my $username    = $params->{username};       # User's username

    $copies ||= 1;    # Default to 1 copy if no cromulent value is passed in

    my $instance = $c->instance;

    my $now = $c->now();

    if ( $client_name eq PRINT_FROM_WEB ) {
        $client = undef;    # Printing from the web does not require a client
    }
    else {
        $client ||= $c->model('DB::Client')    # Fetch the client if it was not passed in
            ->single( { instance => $instance, name => $client_name } );
    }

    $user ||= $c->model('DB::User')            # Fetch the user if they were not passed in
        ->single( { instance => $instance, username => $username } );

    if ($user) {
        my $pdf_string = $print_file->decoded_slurp;
        my $pdf        = PDF::API2->open_scalar($pdf_string);
        my $pages      = $pdf->pages();

        my $printers = $c->get_printer_configuration;
        my $printer  = $printers->{printers}->{$printer_id};


        my $client_id       = $client ? $client->id       : undef;
        my $client_location = $client ? $client->location : undef;
        my $client_type     = $client ? $client->type     : undef;

        my $print_job;
        $c->model('DB')->txn_do(
            sub {
                $print_file = $c->model('DB::PrintFile')->create(
                    {
                        instance        => $instance,
                        filename        => $print_file->filename,
                        content_type    => $print_file->type,
                        data            => $pdf_string,
                        pages           => $pages,
                        client_id       => $client_id,
                        client_name     => $client_name,
                        client_location => $client_location,
                        client_type     => $client_type,
                        user_id         => $user->id,
                        username        => $username,
                        created_on      => $now,
                        updated_on      => $now,
                    }
                );

                $print_job = $c->model('DB::PrintJob')->create(
                    {
                        instance      => $instance,
                        type          => $printer->{type},
                        status        => PRINT_STATUS_PROCESSING,
                        data          => undef,
                        copies        => $copies,
                        printer       => $printer_id,
                        user_id       => $user->id,
                        print_file_id => $print_file->id,
                        created_on    => $now,
                        updated_on    => $now,
                    }
                );
            }
        );

        Libki::Utils::Printing::reevaluate_print_jobs_with_insufficient_funds( $c, { user => $user, print_jobs => [ $print_job ] });

        $c->stash( success => 1 );
    }
    else {

        $c->stash(
            success => 0,
            error   => 'CLIENT NOT FOUND',
            client  => "$instance/$client_name"
        );
    }
}

=head2 reevaluate_print_jobs_with_insufficient_funds

Helper function to check for printable jobs after a users funds have been changed.

=cut

sub reevaluate_print_jobs_with_insufficient_funds {
    my ( $c, $params ) = @_;

    my $user = $params->{user};
    my $print_jobs = $params->{print_jobs};

    my @jobs = $print_jobs ? @$print_jobs : $c->model('DB::PrintJob')->search(
        {
            user_id => $user->id,
            status  => PRINT_STATUS_INSUFFICIENT_FUNDS,
        }
    );

    my $printers = $c->get_printer_configuration->{printers};

    foreach my $j (@jobs) {
        my $printer = $printers->{ $j->printer };
        my $pages   = $j->print_file->pages;
        my $copies  = $j->copies;

        my $status     = PRINT_STATUS_PENDING;
        my $total_cost = $copies * $pages * $printer->{cost_per_page};

        if ( $total_cost <= $user->funds ) {
            $user->funds( $user->funds - $total_cost );
            $j->status(PRINT_STATUS_PENDING);

            $c->model('DB')->txn_do(
                sub {
                    $user->update();
                    $j->update();
                }
            );
        }
        else {
            $j->status(PRINT_STATUS_INSUFFICIENT_FUNDS);
            $j->update();
        }
    }
}

1;
