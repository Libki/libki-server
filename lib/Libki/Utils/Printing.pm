package Libki::Utils::Printing;

use Modern::Perl;

use File::Slurp qw( write_file );
use File::Temp qw( tempfile );
use PDF::API2;
use Try::Tiny;

use constant PRINT_FROM_WEB => '__PRINT_FROM_WEB__';

use constant PRINT_STATUS_PENDING => 'Pending';    # Waiting for PrintManager/CUPS to accept the job
use constant PRINT_STATUS_HELD    => 'Held';       # Waiting for user to release print job
use constant PRINT_STATUS_CANCELED    => 'Canceled';    # Canceled by user
use constant PRINT_STATUS_IN_PROGRESS => 'InProgress';  # Print job is being sent to printer
use constant PRINT_STATUS_DONE        => 'Done';        # Printer has accepted the print job

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
    $copies = 1 unless $copies =~ /^\d+$/; # Set to default if copies is non-numeric

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

        my $pages;
        try {
            my $pdf = PDF::API2->open_scalar($pdf_string);
            $pages = $pdf->pages();
        }
        catch { # PDF may be encrypted, try using pdfinfo instead
            my ( $fh, $fn ) = tempfile();
            write_file( $fn, $pdf_string );
            my $pages = qx{ pdfinfo $fn | awk '/^Pages:/ {print \$2}' };
            chomp $pages;
        };

        my $printers = $c->get_printer_configuration;
        my $printer  = $printers->{printers}->{$printer_id};

        my $client_id       = $client ? $client->id       : undef;
        my $client_location = $client ? $client->location : undef;
        my $client_type     = $client ? $client->type     : undef;

        my $print_job;
        if ($printer) {
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
                            status        => PRINT_STATUS_HELD,
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
        }
        else {
            $c->log->error(
                sprintf(
                    "User id %s printed to non-existent printer id %s from client %s",
                    $user->id, $printer_id, $client ? $client->id : 'Print From Web'
                )
            );
        }

        if ( $print_job && $printer->{auto_release} ) {

            #FIXME: Allow passing the print job object to release instead of re-fetching it
            release( $c, { print_job_id => $print_job->id, user => $user } );
        }

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

=head2 calculate_job_cost

Helper function to calculate the cost of a print job for a given printer

=cut

sub calculate_job_cost {
    my ( $c, $params ) = @_;

    my $print_job  = $params->{print_job};
    my $print_file = $params->{print_file};
    my $printer    = $params->{printer};

    die "Libki::Utils::Printing::calculate_job_cost: missing param print_job" unless $print_job;

    unless ($printer) {
        my $printers = $c->get_printer_configuration;
        $printer = $printers->{printers}->{ $print_job->printer };
    }

    die
        "Libki::Utils::Printing::calculate_job_cost: missing param printer or invalid printer referenced"
        unless $printer;

    $print_file ||= $print_job->print_file;
    my $pages  = $print_file->pages        || 1;
    my $copies = $print_job->copies        || 1;
    my $cpp    = $printer->{cost_per_page} || 0;

    my $cost = $copies * $pages * $cpp;

    return $cost;
}

=head2 cancel

Release a held print job so it can actually be printed.

=cut

sub cancel {
    my ( $c, $print_job_id, $user ) = @_;

    my $instance = $c->instance;

    my $print_job
        = $c->model('DB::PrintJob')->find( { id => $print_job_id, instance => $instance } );

    if ( $user ) {
        return {
            success => 0,
            error   => 'User does not match',
            id      => $print_job_id
        } unless $print_job->user_id == $user->id;
    }

    return {
        success => 0,
        error   => 'Print Job Not Found',
        id      => $print_job_id
    } unless $print_job;

    $print_job->status(PRINT_STATUS_CANCELED);
    return { success => $print_job->update() ? 1 : 0 };

}

=head2 release

Release a held print job so it can actually be printed.

=cut

sub release {
    my ( $c, $params ) = @_;

    my $print_job_id = $params->{print_job_id};
    my $user         = $params->{user};
    my $new_printer  = $params->{printer};

    my $log  = $c->log();
    $log->info("Libki::Utils::Printing::release print_job_id: $params->{print_job_id}, user: $params->{user}, new_printer: $params->{printer}");

    my $instance = $c->instance;

    my $print_job
        = $c->model('DB::PrintJob')->find( { id => $print_job_id, instance => $instance } );

    my $printers = $c->get_printer_configuration;
    my $printer  = $printers->{printers}->{ $print_job->printer };

    if ($new_printer) {
        my $printers = $c->get_printer_configuration;
        my $p        = $printers->{printers}->{$new_printer};

        if ($p) {
            $printer = $p;
            $print_job->printer($new_printer);
            $print_job->update();
        }
        else {
            $c->log->error(
                "Attempt to update printer at release time failed for print job $print_job_id, printer '$new_printer' doesn't exist!"
            );
        }
    }

    if ( $user ) {
        return {
            success => 0,
            error   => 'User does not match',
            id      => $print_job_id
        } unless $print_job->user_id == $user->id;
    } elsif ( !$c->check_user_roles('admin') ) {
        return {
            success => 0,
            error   => 'User does not have rights to release this print job.',
            id      => $print_job_id,
        };
    } else {
        $user = $print_job->user;
    }

    return {
        success => 0,
        error   => 'Print Job Not Found',
        id      => $print_job_id
    } unless $print_job;


    my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );

    return {
        success => 0,
        error   => 'Print File Not Found',
        id      => $print_job->print_file_id
        }
        unless $print_file;

    return {
        success => 0,
        error   => 'Printer Not Found',
        id      => $print_job->printer
        }
        unless $printer;

    my $data = {
        print_job  => $print_job,
        print_file => $print_file,
        printer    => $printer,
    };

    my $total_cost = calculate_job_cost( $c,
        {
            print_job => $print_job,
            printer   => $printer,
        }
    );

    $user->discard_changes; # Let's make absolutely sure we have the correct funds

    if ( $total_cost <= $user->funds ) {
        $user->funds( $user->funds - $total_cost );

        $print_job->status(PRINT_STATUS_PENDING);

        $c->model('DB')->txn_do(
            sub {
                $user->update();
                $print_job->update();
            }
        );
    }
    else {
        return { success => 0, error => 'Insufficient funds' };
    }

    if ( $print_job->type eq 'cups' ) {
        return release_for_cups( $c, $data );
    }
    elsif ( $print_job->type eq 'PrintManager' ) {
        return release_for_print_manager( $c, $data );
    }
}

=head2 release_for_print_manager

Marks the print job as "Pending" so the PrintManager can download and print the print job file.

=cut

sub release_for_print_manager {
    my ( $c, $params ) = @_;

    my $print_job = $params->{print_job};

    my $success = $print_job->update( { status => PRINT_STATUS_PENDING } );

    return {
        success => $success ? 1 : 0,
        message => 'Ok'
    };
}

=head2 release_for_cups

Sends the print job file to CUPS for printing

=cut

sub release_for_cups {
    my ( $c, $params ) = @_;

    my $print_job  = $params->{print_job};
    my $print_file = $params->{print_file};
    my $printer    = $params->{printer};

    my $log  = $c->log();
    my $cups = cups_setup($c);

    my $cups_printer_name = $printer->{name};
    $log->debug( "CUPS Printer name: " . $cups_printer_name );
    my $cups_printer = $cups->getDestination($cups_printer_name);

    return {
        success => 0,
        error   => 'Printer Not Found on CUPS server',
        id      => $print_job->printer
        }
        unless $cups_printer;


    # In order to print to CUPS, the data must be on a file
    # Create a temporary file to print
    my $cups_print_filename = cups_create_print_file( $c, $print_file->data );
    $log->debug( "Created temp file for CUPS printing: " . $cups_print_filename );

    # The job title is the original print file name
    my $cups_print_job_id = $cups_printer->printFile( $cups_print_filename, $print_file->filename );
    unlink($cups_print_filename);

    return {
        success => 0,
        error   => 'Error printing on printer',
        id      => $print_job->printer
        }
        unless $cups_print_job_id;


    my $cups_print_job_data  = $cups_printer->getJob($cups_print_job_id);
    my $cups_print_job_state = $cups_print_job_data->{state_text};
    $print_job->update(
        {
            data       => $cups_print_job_data,
            status     => $cups_print_job_state,
            updated_on => $c->now(),
        }
    );

    return { success => 1, message => 'Ok' };
}


=head2 cups_setup

Initializes the Net::CUPS module with the values from the configuration.

=cut

sub cups_setup {
    require Net::CUPS;

    my ($c) = @_;
    my $instance = $c->instance;

    my $printers_conf = $c->get_printer_configuration;

    my $cups_server   = $printers_conf->{cups}->{server};
    my $cups_username = $printers_conf->{cups}->{username};


    my $cups = Net::CUPS->new();
    $cups->setServer($cups_server);
    $cups->setUsername($cups_username);
    return $cups;
}


=head2 cups_create_print_file

Stores the print data on a temporary file and returns the filename

=cut

sub cups_create_print_file {
    my ( $c, $print_data ) = @_;
    my $instance = $c->instance;

    my $tmp_fh = new File::Temp( UNLINK => 0 );
    binmode($tmp_fh);
    $tmp_fh->write($print_data);
    $tmp_fh->close();
    return $tmp_fh;

}

1;
