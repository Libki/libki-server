package Libki::Utils::Printing;

use Modern::Perl;

use PDF::API2;

use constant PRINT_FROM_WEB => '__PRINT_FROM_WEB__';

=head2 create_print_job_and_file

Helper method to create a print_job and print_file entry from the given PDF and data.

Printing may be initiated by a Libki Client via the API,
or by uploading a file to print via the public self-service web interface

=cut

sub create_print_job_and_file {
    my ( $c, $params ) = @_;

    my $client      = $params->{client}; # DB::Client object, optional
    my $client_name = $params->{client_name}; # Client name file was printed from, if any
    my $copies      = $params->{copies}; # How many copies of this file are to be printed
    my $location    = $params->{location}; # Client location, if any
    my $print_file  = $params->{print_file}; # Catalyst::Request::Upload object
    my $printer_id  = $params->{printer_id}; # Printer id from printer configuration setting
    my $user        = $params->{user}; # DB::User object, optional
    my $username    = $params->{username}; # User's username

    $copies ||= 1; # Default to 1 copy if no cromulent value is passed in

    my $instance = $c->instance;

    my $now = $c->now();

    if ( $client_name eq PRINT_FROM_WEB ) {
        $client = undef; # Printing from the web does not require a client
    }
    else {
        $client ||= $c->model( 'DB::Client' ) # Fetch the client if it was not passed in
            ->single( { instance => $instance, name => $client_name } );
    }

    $user ||= $c->model( 'DB::User' ) # Fetch the user if they were not passed in
        ->single( { instance => $instance, username => $username } );

    if ( $user ) {
        my $pdf_string = $print_file->decoded_slurp;
        my $pdf        = PDF::API2->open_scalar($pdf_string);
        my $pages      = $pdf->pages();

        my $printers = $c->get_printer_configuration;
        my $printer  = $printers->{printers}->{$printer_id};

        my $client_id = $client ? $client->id : undef;
        my $client_location = $client ? $client->location : undef;
        my $client_type = $client ? $client->type : undef;

        $c->model('DB')->txn_do(sub {
            $print_file = $c->model( 'DB::PrintFile' )->create(
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

            my $print_job = $c->model( 'DB::PrintJob' )->create(
                {
                    instance      => $instance,
                    type          => $printer->{type},
                    status        => 'Pending',
                    data          => undef,
                    copies        => $copies,
                    printer       => $printer_id,
                    user_id       => $user->id,
                    print_file_id => $print_file->id,
                    created_on    => $now,
                    updated_on    => $now,
                }
            );
        });

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

1;
