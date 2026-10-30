package Libki::Utils::Printing;

use Modern::Perl;

use File::Temp qw( tempfile );
use JSON qw( to_json from_json );
use PDF::API2;
use Try::Tiny;

use constant PRINT_FROM_WEB => '__PRINT_FROM_WEB__';

use constant PRINT_STATUS_PENDING => 'Pending';    # Waiting for PrintManager/CUPS to accept the job
use constant PRINT_STATUS_HELD    => 'Held';       # Waiting for user to release print job
use constant PRINT_STATUS_CANCELED    => 'Canceled';    # Canceled by user
use constant PRINT_STATUS_IN_PROGRESS => 'InProgress';  # Print job is being sent to printer
use constant PRINT_STATUS_DONE        => 'Done';        # Printer has accepted the print job

use constant MAX_PRINT_PDF_BYTES => 25 * 1024 * 1024;
use constant MAX_PRINT_PDF_PAGES => 1000;

=head2 inspect_pdf_data

Validate an uploaded PDF and return its positive page count.  The client does
not send a trustworthy multipart MIME type, so validation uses a bounded body,
a PDF header, and two independent PDF parsers.  No filename or document data is
passed through a shell.

=cut

sub inspect_pdf_data {
    my ($pdf_string) = @_;

    return unless defined $pdf_string;
    my $bytes = length($pdf_string);
    return unless $bytes > 0 && $bytes <= MAX_PRINT_PDF_BYTES;

    my $header = substr( $pdf_string, 0, 1024 );
    return unless $header =~ /%PDF-(?:1[.][0-7]|2[.]0)/;

    my $pages;
    try {
        my $pdf = PDF::API2->open_scalar($pdf_string);
        $pages = $pdf->pages();
    }
    catch {
        $pages = undef;
    };

    $pages = _pdfinfo_pages($pdf_string)
        unless defined $pages && $pages =~ /^[0-9]+$/ && $pages > 0;

    return unless defined $pages && $pages =~ /^[0-9]+$/;
    return unless $pages > 0 && $pages <= MAX_PRINT_PDF_PAGES;
    return int($pages);
}

sub safe_pdf_filename {
    my ($filename) = @_;
    return unless defined $filename && length($filename) <= 1024;

    $filename =~ s{.*[\\/]}{};
    my ($stem) = $filename =~ /^(.*)[.]pdf$/i;
    return unless defined $stem;

    $stem =~ s/[^A-Za-z0-9._ ()-]+/_/g;
    $stem =~ s/^[.]+/_/;
    $stem = substr( $stem, 0, 196 );
    $stem = 'print' unless length $stem;

    return "$stem.pdf";
}

sub _pdfinfo_pages {
    my ($pdf_string) = @_;

    my ( $fh, $filename ) = tempfile( SUFFIX => '.pdf', UNLINK => 1 );
    binmode $fh;
    print {$fh} $pdf_string or return;
    close $fh or return;

    open my $pdfinfo, '-|', '/usr/bin/pdfinfo', $filename or return;
    my $pages;
    while ( my $line = <$pdfinfo> ) {
        $pages = $1 if $line =~ /^Pages:[[:space:]]+([0-9]+)[[:space:]]*$/;
    }
    my $ok = close $pdfinfo;

    return $ok ? $pages : undef;
}

sub _reject_print_upload {
    my ( $c, $error ) = @_;
    $c->stash(
        success => 0,
        error   => $error,
    );
    return;
}

=head2 create_print_job_and_file

Helper function to create a print_job and print_file entry from the given PDF and data.

Printing may be initiated by a Libki Client via the API,
or by uploading a file to print via the public self-service web interface

=cut

sub create_print_job_and_file {
    my ( $c, $params ) = @_;

    my $client      = $params->{client};
    my $client_name = $params->{client_name};
    my $copies      = $params->{copies};
    my $print_file  = $params->{print_file};
    my $printer_id  = $params->{printer_id};
    my $user        = $params->{user};
    my $job_data    = $params->{data};
    my $username    = $params->{username};

    $copies ||= 1;
    $copies = 1
        unless $copies =~ /^[0-9]+$/ && $copies >= 1 && $copies <= 99;

    my $instance = $c->instance;
    my $now      = $c->now();

    if ( $client_name eq PRINT_FROM_WEB ) {
        $client = undef;
    }
    else {
        $client ||= $c->model('DB::Client')
            ->single( { instance => $instance, name => $client_name } );
    }

    $user ||= $c->model('DB::User')
        ->single( { instance => $instance, username => $username } );

    return _reject_print_upload( $c, 'CLIENT_NOT_FOUND' ) unless $user;
    return _reject_print_upload( $c, 'MISSING_PRINT_FILE' ) unless $print_file;

    my $filename = safe_pdf_filename( eval { $print_file->filename } );
    return _reject_print_upload( $c, 'INVALID_PDF' ) unless $filename;

    my $pdf_string = eval { $print_file->decoded_slurp };
    return _reject_print_upload( $c, 'INVALID_PDF' )
        unless defined $pdf_string;

    my $pages = inspect_pdf_data($pdf_string);
    return _reject_print_upload( $c, 'INVALID_PDF' ) unless $pages;

    my $printers = $c->get_printer_configuration;
    my $printer  = $printers->{printers}->{$printer_id};
    return _reject_print_upload( $c, 'INVALID_PRINTER' ) unless $printer;

    if ( $client && $printer->{allowed_client_locations} ) {
        my @allowed_locations = ref $printer->{allowed_client_locations} eq 'ARRAY'
            ? @{ $printer->{allowed_client_locations} }
            : ( $printer->{allowed_client_locations} );
        my $client_location = $client->location
            ? $client->location->code
            : q{};

        return _reject_print_upload(
            $c, 'PRINTER_NOT_AVAILABLE_AT_CLIENT_LOCATION'
        ) unless grep { defined $_ && $_ eq $client_location }
            @allowed_locations;
    }

    my $client_id       = $client ? $client->id       : undef;
    my $client_type     = $client ? $client->type     : undef;
    my $client_location = $client && $client->location
        ? $client->location->code
        : undef;
    my $printer_location  = $printer->{location};
    my $printfile_location = $printer_location
        ? $printer_location
        : $client_location;

    my $print_job;
    $c->model('DB')->txn_do(
        sub {
            $print_file = $c->model('DB::PrintFile')->create(
                {
                    instance        => $instance,
                    filename        => $filename,
                    content_type    => 'application/pdf',
                    data            => $pdf_string,
                    pages           => $pages,
                    client_id       => $client_id,
                    client_name     => $client_name,
                    client_location => $printfile_location,
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
                    data          => $job_data,
                    copies        => $copies,
                    printer       => $printer_id,
                    user_id       => $user->id,
                    print_file_id => $print_file->id,
                    created_on    => $now,
                    updated_on    => $now,
                }
            );

            $c->model('DB::Statistic')->create(
                {
                    instance   => $c->instance,
                    username   => $username,
                    action     => 'PRINT_JOB_CREATED',
                    created_on => $c->now,
                    session_id => scalar $c->sessionid,
                    info       => to_json(
                        {
                            print_job_id    => $print_job->id,
                            print_file_id   => $print_file->id,
                            client_id       => $client_id,
                            client_location => $printfile_location,
                            client_name     => $client_name,
                            client_type     => $client_type,
                            content_type    => $print_file->content_type,
                            copies          => $copies,
                            filename        => $print_file->filename,
                            pages           => $pages,
                            printer         => $printer_id,
                            user_id         => $user->id,
                        }
                    ),
                }
            );
        }
    );

    if ( $print_job && $printer->{auto_release}
        && (  $printer->{auto_release} eq 'yes'
            || ( $printer->{auto_release} eq 'client' && $client_name ne PRINT_FROM_WEB )
            || ( $printer->{auto_release} eq 'public' && $client_name eq PRINT_FROM_WEB )
        ) ) {

        # FIXME: Allow passing the print job object to release instead of re-fetching it.
        release( $c, { print_job_id => $print_job->id, user => $user } );
    }

    $c->stash( success => 1 );
    return $print_job;
}

=head2 calculate_job_cost

Helper function to calculate the cost of a print job for a given printer.
Returns a list containing the calculated cost and the gratis discount applied.

    my ( $cost, $gratis_discount ) = calculate_job_cost( $c, { print_job => $job } );

=cut

sub calculate_job_cost {
    my ( $c, $params ) = @_;

    my $GratisPrintingMethod = $c->setting("GratisPrintingMethod");

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
    my $copies = $params->{copies} // ($print_job->copies || 1);
    my $cpp    = $printer->{cost_per_page} || 0;

    my $total_pages = $pages * $copies;

    my $gratis_discount = 0;
    my $user = $print_job->user();

    if ( $GratisPrintingMethod  eq 'pages' ) {
        if ( $total_pages >= $user->gratis_print_balance ) {
            $gratis_discount = $user->gratis_print_balance;
            $total_pages -= $user->gratis_print_balance;        
        } else {
            $gratis_discount = $total_pages;
            $total_pages = 0;
        }
    } 

    my $cost = $total_pages * $cpp;

    if ( $GratisPrintingMethod  eq 'funds' ) {
        if ( $cost >= $user->gratis_print_balance ) {
            $gratis_discount = $user->gratis_print_balance;
            $cost -= $user->gratis_print_balance;
        } else {
            $gratis_discount = $cost;
            $cost = 0;
        }
    } 

    return ($cost, $gratis_discount);
}

=head2 printer_allows_location

Return true when a printer is available to the location recorded on a print
file. Printers without an allow-list retain the upstream unrestricted
behavior.

=cut

sub printer_allows_location {
    my ( $printer, $client_location ) = @_;

    return 0 unless $printer;
    return 1 unless exists $printer->{allowed_client_locations};

    my @allowed_locations = ref $printer->{allowed_client_locations} eq 'ARRAY'
        ? @{ $printer->{allowed_client_locations} }
        : ( $printer->{allowed_client_locations} );

    return ( scalar grep {
        defined $_ && defined $client_location && $_ eq $client_location
    } @allowed_locations ) ? 1 : 0;
}

=head2 cups_job_options

Build the server-authoritative CUPS options for a configured queue. These
options override choices embedded by the Windows print dialog so that a B&W
queue cannot accidentally submit color and City queues remain one-sided.

=cut

sub cups_job_options {
    my ( $print_job, $printer ) = @_;

    my %options = ( copies => int( $print_job->copies || 1 ) );

    my $chroming = lc( $printer->{chroming} || q{} );
    $options{'print-color-mode'} = 'monochrome'
        if $chroming eq 'monochrome';
    $options{'print-color-mode'} = 'color'
        if $chroming eq 'color';

    my $plexing = lc( $printer->{plexing} || q{} );
    $options{sides} = 'one-sided'
        if $plexing eq 'simplex';
    $options{sides} = 'two-sided-long-edge'
        if $plexing eq 'duplex';

    return \%options;
}

=head2 build_release_preview

Build the authoritative, side-effect-free staff review payload for one print
job. This intentionally performs no accounting and never contacts CUPS.

=cut

sub requested_copies {
    my ($value, $fallback) = @_;
    return $fallback unless defined $value;
    return undef unless $value =~ /\A[0-9]{1,2}\z/ && $value >= 1 && $value <= 99;
    return 0 + $value;
}

sub build_release_preview {
    my ( $c, $params ) = @_;

    my $print_job_id = $params->{print_job_id};
    my $instance     = $c->instance;
    my $print_job    = $c->model('DB::PrintJob')->find(
        { id => $print_job_id, instance => $instance }
    );

    return {
        success => 0,
        error   => 'PRINT_JOB_NOT_FOUND',
        id      => $print_job_id,
    } unless $print_job;

    my $print_file = $c->model('DB::PrintFile')->find(
        $print_job->print_file_id
    );
    return {
        success => 0,
        error   => 'PRINT_FILE_NOT_FOUND',
        id      => $print_job->print_file_id,
    } unless $print_file;

    my $printers = $c->get_printer_configuration;
    my $printer  = $printers->{printers}->{ $print_job->printer };
    return {
        success => 0,
        error   => 'PRINTER_NOT_FOUND',
        id      => $print_job->printer,
    } unless $printer;

    my $client_location = $print_file->client_location;
    return {
        success => 0,
        error   => 'PRINTER_NOT_AVAILABLE_AT_CLIENT_LOCATION',
        id      => $print_job->printer,
    } unless printer_allows_location( $printer, $client_location );

    my $user = $print_job->user;
    return {
        success => 0,
        error   => 'PRINT_USER_NOT_FOUND',
        id      => $print_job->user_id,
    } unless $user;

    my $requested_copies = requested_copies($params->{copies}, $print_job->copies || 1);
    return { success => 0, error => 'INVALID_COPIES' } unless defined $requested_copies;
    my ( $amount_due, $gratis_discount ) = calculate_job_cost(
        $c,
        {
            print_job  => $print_job,
            copies     => $requested_copies,
            print_file => $print_file,
            printer    => $printer,
        }
    );

    my $firstname   = eval { $user->firstname } || q{};
    my $lastname    = eval { $user->lastname }  || q{};
    my $patron_name = join q{ }, grep { length } ( $firstname, $lastname );
    $patron_name = $user->username unless length $patron_name;

    my $staff_release_enabled
        = ( $printers->{staff_print_release} || 'disabled' ) eq 'enabled'
        ? 1
        : 0;
    my $pages  = $print_file->pages || 1;
    my $copies = $requested_copies;
    my $print_data = $print_file->data;
    my $job_data = $print_job->data;
    my $is_mobile_print
        = ref($job_data) eq 'HASH'
        && ($job_data->{source} // q{}) eq 'mobileprint'
        ? 1
        : 0;
    my $release_allowed
        = $staff_release_enabled && $print_job->status eq PRINT_STATUS_HELD
        ? 1
        : 0;
    my $reprint_allowed
        = $staff_release_enabled
        && $print_job->status eq PRINT_STATUS_DONE
        && $print_job->type eq 'cups'
        && defined $print_data
        && length $print_data
        ? 1
        : 0;

    return {
        success                     => 1,
        print_job_id                => $print_job->id,
        status                      => $print_job->status,
        printer_id                  => $print_job->printer,
        printer_name                => $printer->{public_printer_name} || $print_job->printer,
        release_location            => $printer->{release_location} || $client_location || q{},
        client_name                 => $print_file->client_name || q{},
        client_location             => $client_location || q{},
        library_card                => $user->username,
        identifier_label            => $is_mobile_print ? 'Phone number' : 'Library card number',
        mobile_file_count           => $is_mobile_print
            ? 0 + ($job_data->{mobileprint_file_count} || 1)
            : undef,
        patron_name                 => $patron_name,
        filename                    => $print_file->filename,
        pages                       => 0 + $pages,
        copies                      => 0 + $copies,
        total_pages                 => 0 + ( $pages * $copies ),
        amount_due                  => sprintf( '%.2f', $amount_due ),
        gratis_discount             => sprintf( '%.2f', $gratis_discount ),
        staff_print_release_enabled => $staff_release_enabled,
        release_allowed             => $release_allowed,
        reprint_allowed             => $reprint_allowed,
        action_mode                 => $release_allowed ? 'release'
                                     : $reprint_allowed ? 'reprint'
                                     : 'review',
    };
}

=head2 create_reprint_job

Create a new held print job from a completed CUPS job. The source job remains
immutable so the original release history is preserved and every reprint has
its own cash and printer audit trail.

=cut

sub create_reprint_job {
    my ( $c, $params ) = @_;

    my $source_print_job_id = $params->{print_job_id};
    my $expected_amount     = $params->{expected_amount};
    my $instance            = $c->instance;

    return { success => 0, error => 'User does not have rights to reprint this print job.' }
        unless $c->check_user_roles('admin');

    my $printers = $c->get_printer_configuration;
    return { success => 0, error => 'STAFF_PRINT_RELEASE_DISABLED' }
        unless ( $printers->{staff_print_release} || 'disabled' ) eq 'enabled';

    my $source_print_job = $c->model('DB::PrintJob')->find(
        { id => $source_print_job_id, instance => $instance }
    );
    return {
        success => 0,
        error   => 'Print Job Not Found',
        id      => $source_print_job_id,
    } unless $source_print_job;

    return {
        success => 0,
        error   => 'PRINT_JOB_NOT_COMPLETED',
        id      => $source_print_job_id,
        status  => $source_print_job->status,
    } unless $source_print_job->status eq PRINT_STATUS_DONE;

    return {
        success => 0,
        error   => 'UNSUPPORTED_REPRINT_JOB_TYPE',
        id      => $source_print_job_id,
        type    => $source_print_job->type,
    } unless $source_print_job->type eq 'cups';

    my $print_file = $c->model('DB::PrintFile')->find(
        $source_print_job->print_file_id
    );
    return {
        success => 0,
        error   => 'PRINT_FILE_NOT_FOUND',
        id      => $source_print_job->print_file_id,
    } unless $print_file;
    my $print_data = $print_file->data;
    return {
        success => 0,
        error   => 'PRINT_FILE_DATA_UNAVAILABLE',
        id      => $source_print_job->print_file_id,
    } unless defined $print_data && length $print_data;

    my $printer = $printers->{printers}->{ $source_print_job->printer };
    return {
        success => 0,
        error   => 'PRINTER_NOT_FOUND',
        id      => $source_print_job->printer,
    } unless $printer;
    return {
        success => 0,
        error   => 'PRINTER_NOT_AVAILABLE_AT_CLIENT_LOCATION',
        id      => $source_print_job->printer,
    } unless printer_allows_location( $printer, $print_file->client_location );

    my $copies = requested_copies($params->{copies}, $source_print_job->copies || 1);
    return { success => 0, error => 'INVALID_COPIES' } unless defined $copies;
    my $request_id = $params->{request_id};
    return { success => 0, error => 'INVALID_REQUEST_ID' }
        if defined $request_id && $request_id !~ /\A[a-zA-Z0-9-]{16,64}\z/;
    my ( $amount_due ) = calculate_job_cost(
        $c,
        {
            print_job  => $source_print_job,
            copies     => $copies,
            print_file => $print_file,
            printer    => $printer,
        }
    );
    my $authoritative_amount = sprintf( '%.2f', $amount_due );
    return {
        success => 0,
        error   => 'PRINT_COST_CHANGED',
        amount_due => $authoritative_amount,
    } unless defined $expected_amount
        && $expected_amount =~ /\A[0-9]+(?:[.][0-9]{1,2})?\z/
        && sprintf( '%.2f', $expected_amount ) eq $authoritative_amount;

    my $now   = $c->now;
    my $actor = $c->user ? $c->user->username : 'administrative reprint';
    my $reprint_job;

    $c->model('DB')->txn_do(
        sub {
            if (defined $request_id) {
                # Serialize requests against the immutable source job; audit retains
                # request identity even after CUPS replaces the new job's data.
                $c->model('DB::PrintJob')->search(
                    { id => $source_print_job->id, instance => $instance },
                    { for => 'update' }
                )->single;
                my @prior = $c->model('DB::Statistic')->search({
                    instance => $instance, action => 'PRINT_JOB_REPRINT_CREATED',
                    info => { like => '%' . $request_id . '%' },
                })->all;
                for my $stat (@prior) {
                    my $info = eval { from_json($stat->info) } || {};
                    if (($info->{request_id} || '') eq $request_id
                        && $info->{source_print_job_id} == $source_print_job->id) {
                        $reprint_job = $c->model('DB::PrintJob')->find(
                            { id => $info->{reprint_job_id}, instance => $instance });
                        return if $reprint_job;
                    }
                }
            }
            $reprint_job = $c->model('DB::PrintJob')->create(
                {
                    instance      => $instance,
                    type          => $source_print_job->type,
                    status        => PRINT_STATUS_HELD,
                    data          => undef,
                    copies        => $copies,
                    printer       => $source_print_job->printer,
                    user_id       => $source_print_job->user_id,
                    print_file_id => $source_print_job->print_file_id,
                    created_on    => $now,
                    updated_on    => $now,
                }
            );

            $c->model('DB::Statistic')->create(
                {
                    instance   => $instance,
                    username   => $actor,
                    action     => 'PRINT_JOB_REPRINT_CREATED',
                    created_on => $now,
                    session_id => $c->sessionid,
                    info       => to_json(
                        {
                            source_print_job_id => $source_print_job->id,
                            reprint_job_id      => $reprint_job->id,
                            print_file_id       => $source_print_job->print_file_id,
                            printer             => $source_print_job->printer,
                            copies              => $copies,
                            request_id          => $request_id,
                            amount_due          => $authoritative_amount,
                        }
                    ),
                }
            );
        }
    );

    return {
        success             => $reprint_job ? 1 : 0,
        source_print_job_id => $source_print_job->id,
        reprint_job_id      => $reprint_job ? $reprint_job->id : undef,
        amount_due          => $authoritative_amount,
    };
}

=head2 cancel

Release a held print job so it can actually be printed.

=cut

sub cancel {
    my ( $c, $print_job_id, $user ) = @_;

    my $instance = $c->instance;

    my $print_job
        = $c->model('DB::PrintJob')->find( { id => $print_job_id, instance => $instance } );

    return {
        success => 0,
        error   => 'Print Job Not Found',
        id      => $print_job_id
    } unless $print_job;

    if ( $user ) {
        return {
            success => 0,
            error   => 'User does not match',
            id      => $print_job_id
        } unless $print_job->user_id == $user->id;
    }

    my $cancel_actor = $user
        ? $user->username
        : $c->user
            ? $c->user->username
            : 'administrative cancellation';

    $print_job->status(PRINT_STATUS_CANCELED);

    $c->model('DB::Statistic')->create(
        {
            instance   => $c->instance,
            username   => $cancel_actor,
            action     => 'PRINT_JOB_CANCELED',
            created_on => $c->now,
            session_id => $c->sessionid,
            info       => to_json(
                {
                    print_job_id    => $print_job->id,
                }
            ),
        }
    );

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
    my $requested_user  = $user;
    my $payment_method  = $params->{payment_method} || 'account';
    my $expected_amount = $params->{expected_amount};

    my $log  = $c->log();
    my $release_actor = $user
        ? $user->username
        : $c->user
            ? $c->user->username
            : 'administrative release';

    return { success => 0, error => 'INVALID_PAYMENT_METHOD' }
        unless $payment_method eq 'account' || $payment_method eq 'cash';
    return { success => 0, error => 'CASH_RELEASE_REQUIRES_STAFF' }
        if $payment_method eq 'cash' && $requested_user;

    $log->info(
        "Libki::Utils::Printing::release print_job_id: $print_job_id, user: $release_actor"
    );

    my $instance = $c->instance;

    my $print_job
        = $c->model('DB::PrintJob')->find( { id => $print_job_id, instance => $instance } );

    return {
        success => 0,
        error   => 'Print Job Not Found',
        id      => $print_job_id
    } unless $print_job;

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

    my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );
    return {
        success => 0,
        error   => 'Print Job Is Not Held',
        id      => $print_job_id,
        status  => $print_job->status,
    } unless $print_job->status eq PRINT_STATUS_HELD;

    return {
        success => 0,
        error   => 'Unsupported Print Job Type',
        id      => $print_job_id,
        type    => $print_job->type,
    } unless $print_job->type eq 'cups' || $print_job->type eq 'PrintManager';

    my $printers = $c->get_printer_configuration;
    my $printer  = $printers->{printers}->{ $print_job->printer };

    if ($new_printer) {
        my $p = $printers->{printers}->{$new_printer};

        unless ($p) {
            $c->log->error(
                "Attempt to update printer at release time failed for print job $print_job_id, printer '$new_printer' doesn't exist!"
            );

            return {
                success => 0,
                error   => 'Printer Not Found',
                id      => $new_printer,
            };
        }

        $printer = $p;
        $print_job->printer($new_printer);
    }


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

    return {
        success => 0,
        error   => 'PRINTER_NOT_AVAILABLE_AT_CLIENT_LOCATION',
        id      => $print_job->printer,
    } unless printer_allows_location( $printer, $print_file->client_location );

    if ( $print_job->type eq 'cups'
        && ( $printers->{staff_print_release} || 'disabled' ) ne 'enabled' ) {
        return {
            success => 0,
            error   => 'STAFF_PRINT_RELEASE_DISABLED',
            id      => $print_job_id,
        };
    }

    my $copies = requested_copies($params->{copies}, $print_job->copies || 1);
    return { success => 0, error => 'INVALID_COPIES' } unless defined $copies;
    return { success => 0, error => 'COPY_CHANGE_REQUIRES_STAFF_CASH' }
        if defined $params->{copies} && ($payment_method ne 'cash' || $requested_user);
    my $data = {
        print_job  => $print_job,
        print_file => $print_file,
        printer    => $printer,
    };

    my ($total_cost, $gratis_discount) = calculate_job_cost( $c,
        {
            print_job => $print_job,
            copies    => $copies,
            printer   => $printer,
        }
    );

    if ( defined $expected_amount ) {
        return { success => 0, error => 'INVALID_EXPECTED_AMOUNT' }
            unless $expected_amount =~ /^[0-9]+(?:[.][0-9]{1,2})?$/;

        my $expected_cents = int( ( $expected_amount * 100 ) + 0.5 );
        my $current_cents  = int( ( $total_cost * 100 ) + 0.5 );
        return {
            success    => 0,
            error      => 'PRINT_COST_CHANGED',
            amount_due => sprintf( '%.2f', $total_cost ),
        } unless $expected_cents == $current_cents;
    }

    $user->discard_changes; # Let's make absolutely sure we have the correct funds

    return { success => 0, error => 'Insufficient funds' }
        if $payment_method eq 'account' && $total_cost > $user->funds;

    # Claim the held job with a single conditional UPDATE. The earlier status
    # check gives the caller a useful response; this compare-and-swap is what
    # prevents simultaneous requests from both charging/submitting the job.
    my $claimed = $c->model('DB::PrintJob')->search(
        {
            id       => $print_job_id,
            instance => $instance,
            status   => PRINT_STATUS_HELD,
        }
    )->update(
        {
            status     => PRINT_STATUS_IN_PROGRESS,
            copies     => $copies,
            updated_on => $c->now,
        }
    );

    return {
        success => 0,
        error   => 'Print Job Is Not Held',
        id      => $print_job_id,
    } unless $claimed && $claimed == 1;

    $print_job->status(PRINT_STATUS_IN_PROGRESS);
    $print_job->copies($copies);

    my $gratis_balance_before = $user->gratis_print_balance;
    my $accounting_error;

    try {
        $c->model('DB')->txn_do(
            sub {
                if ( $payment_method eq 'account' ) {
                    $user->debit_funds(
                        $c,
                        $total_cost,
                        provider => 'internal',
                        notes    => "Print job $print_job_id release",
                    ) if $total_cost;
                }
                else {
                    $c->model('DB::Statistic')->create(
                        {
                            instance   => $c->instance,
                            username   => $release_actor,
                            action     => 'PRINT_PAYMENT_CASH',
                            created_on => $c->now,
                            session_id => $c->sessionid // '',
                            info       => to_json(
                                {
                                    print_job_id => $print_job->id,
                                    user_id      => $user->id,
                                    amount       => sprintf( '%.2f', $total_cost ),
                                }
                            ),
                        }
                    );
                }

                $user->gratis_print_balance(
                    $gratis_balance_before - $gratis_discount
                );

                $user->update();

                die "Unable to mark print job $print_job_id pending"
                    unless $print_job->update(
                        {
                            status      => PRINT_STATUS_PENDING,
                            released_on => $c->now,
                            updated_on  => $c->now,
                        }
                    );

                if ( $gratis_discount > 0 ) {
                    $c->model('DB::Statistic')->create(
                        {
                            instance   => $c->instance,
                            username   => $user->username,
                            action     => 'GRATIS_DISCOUNT',
                            created_on => $c->now,
                            session_id => $c->sessionid,
                            info       => to_json(
                                {
                                    print_job_id    => $print_job->id,
                                    gratis_discount => $gratis_discount,
                                }
                            ),
                        }
                    );
                }

                # PrintManager has no external side effect at release time:
                # the accounting, Pending status, and audit statistic can be
                # committed atomically before the manager polls for the job.
                if ( $print_job->type eq 'PrintManager' ) {
                    $c->model('DB::Statistic')->create(
                        {
                            instance   => $c->instance,
                            username   => $c->user ? $c->user->username : '',
                            action     => 'PRINT_JOB_RELEASED',
                            created_on => $c->now,
                            session_id => $c->sessionid // '',
                            info       => to_json(
                                {
                                    print_job_id => $print_job->id,
                                }
                            ),
                        }
                    );
                }
            }
        );
    }
    catch {
        $accounting_error = $_;
    };

    if ($accounting_error) {
        $log->error(
            "Unable to account for print job $print_job_id release: $accounting_error"
        );

        # The transaction failed before any print backend was called. Restore
        # only our own claim; a changed status means another actor intervened.
        $c->model('DB::PrintJob')->search(
            {
                id       => $print_job_id,
                instance => $instance,
                status   => PRINT_STATUS_IN_PROGRESS,
            }
        )->update(
            {
                status     => PRINT_STATUS_HELD,
                updated_on => $c->now,
            }
        );

        return {
            success => 0,
            error   => 'Unable to account for print release',
            id      => $print_job_id,
        };
    }

    return { success => 1, message => 'Ok' }
        if $print_job->type eq 'PrintManager';

    my $result = release_for_cups( $c, $data );
    return $result if $result->{success};

    # A CUPS failure before an accepted job is safe to compensate and retry.
    # If submission may have happened, leave the job non-Held and charged so a
    # staff retry cannot create a duplicate physical print.
    return $result unless $result->{safe_to_retry};

    my $compensation_error;
    try {
        $c->model('DB')->txn_do(
            sub {
                if ( $payment_method eq 'account' ) {
                    $user->credit_funds(
                        $c,
                        $total_cost,
                        provider => 'internal',
                        notes    => "Automatic refund for failed print job $print_job_id release",
                    ) if $total_cost;
                }
                else {
                    $c->model('DB::Statistic')->create(
                        {
                            instance   => $c->instance,
                            username   => $release_actor,
                            action     => 'PRINT_PAYMENT_CASH_VOID',
                            created_on => $c->now,
                            session_id => $c->sessionid // '',
                            info       => to_json(
                                {
                                    print_job_id => $print_job->id,
                                    amount       => sprintf( '%.2f', $total_cost ),
                                }
                            ),
                        }
                    );
                }

                $user->gratis_print_balance($gratis_balance_before);
                $user->update();

                my $restored = $c->model('DB::PrintJob')->search(
                    {
                        id       => $print_job_id,
                        instance => $instance,
                        status   => PRINT_STATUS_PENDING,
                    }
                )->update(
                    {
                        status      => PRINT_STATUS_HELD,
                        released_on => undef,
                        updated_on  => $c->now,
                    }
                );

                die "Unable to restore failed print job $print_job_id to Held"
                    unless $restored && $restored == 1;

                $c->model('DB::Statistic')->create(
                    {
                        instance   => $c->instance,
                        username   => $c->user ? $c->user->username : '',
                        action     => 'PRINT_JOB_RELEASE_FAILED',
                        created_on => $c->now,
                        session_id => $c->sessionid // '',
                        info       => to_json(
                            {
                                print_job_id => $print_job->id,
                                refunded     => $total_cost,
                            }
                        ),
                    }
                );
            }
        );
    }
    catch {
        $compensation_error = $_;
    };

    if ($compensation_error) {
        $log->error(
            "Automatic compensation failed for print job $print_job_id: $compensation_error"
        );
        $result->{manual_review} = 1;
        $result->{safe_to_retry} = 0;
        $result->{error} = 'Print release failed; automatic refund requires review';
    }

    return $result;
}

=head2 release_for_print_manager

Marks the print job as "Pending" so the PrintManager can download and print the print job file.

=cut

sub release_for_print_manager {
    my ( $c, $params ) = @_;

    my $print_job = $params->{print_job};

    my $success = $print_job->update( { status => PRINT_STATUS_PENDING } );

    $c->model('DB::Statistic')->create(
        {
            instance   => $c->instance,
            username   => $c->user ? $c->user->username : '',
            action     => 'PRINT_JOB_RELEASED',
            created_on => $c->now,
            session_id => $c->sessionid // '',
            info       => to_json(
                {
                    print_job_id    => $print_job->id,
                }
            ),
        }
    );

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
    my ( $cups, $setup_error );
    try {
        $cups = cups_setup($c);
    }
    catch {
        $setup_error = $_;
    };

    if ($setup_error) {
        $log->error("Unable to initialize CUPS: $setup_error");
        return {
            success       => 0,
            error         => 'Unable to initialize CUPS',
            safe_to_retry => 1,
        };
    }

    my $cups_printer_name = $printer->{name} || $printer->{physical_printer_name};
    $log->debug( "CUPS Printer name: " . $cups_printer_name );
    my ( $cups_printer, $destination_error );
    try {
        $cups_printer = $cups->getDestination($cups_printer_name);
    }
    catch {
        $destination_error = $_;
    };

    if ($destination_error) {
        $log->error("Unable to query CUPS destination $cups_printer_name: $destination_error");
        return {
            success       => 0,
            error         => 'Unable to query printer on CUPS server',
            id            => $print_job->printer,
            safe_to_retry => 1,
        };
    }

    return {
        success       => 0,
        error         => 'Printer Not Found on CUPS server',
        id            => $print_job->printer,
        safe_to_retry => 1,
        }
        unless $cups_printer;

    my $cups_options = cups_job_options( $print_job, $printer );
    my $option_error;
    try {
        for my $name ( sort keys %{$cups_options} ) {
            $cups_printer->addOption( $name, "$cups_options->{$name}" );
        }
    }
    catch {
        $option_error = $_;
    };

    if ($option_error) {
        $log->error(
            "Unable to apply authoritative CUPS options for print job "
                . $print_job->id . ": $option_error"
        );
        return {
            success       => 0,
            error         => 'Unable to apply printer policy',
            safe_to_retry => 1,
        };
    }


    # In order to print to CUPS, the data must be on a file
    # Create a temporary file to print
    my ( $cups_print_filename, $print_file_error );
    try {
        $cups_print_filename = cups_create_print_file( $c, $print_file->data );
    }
    catch {
        $print_file_error = $_;
    };

    if ($print_file_error) {
        $log->error("Unable to create temporary CUPS file: $print_file_error");
        return {
            success       => 0,
            error         => 'Unable to prepare the print job for CUPS',
            safe_to_retry => 1,
        };
    }

    $log->debug( "Created temp file for CUPS printing: " . $cups_print_filename );

    # Include the immutable Libki job id so an uncertain submission can be
    # reconciled in CUPS without exposing the patron's card number.
    my $job_title = join q{-}, 'libki', $c->instance, $print_job->id, $print_file->filename;
    my ( $cups_print_job_id, $submission_error );
    try {
        $cups_print_job_id = $cups_printer->printFile( $cups_print_filename, $job_title );
    }
    catch {
        $submission_error = $_;
    };
    unlink($cups_print_filename);

    if ($submission_error) {
        $log->error(
            "CUPS submission outcome is uncertain for print job " . $print_job->id . ": $submission_error"
        );
        return {
            success       => 0,
            error         => 'CUPS submission outcome requires staff review',
            id            => $print_job->printer,
            safe_to_retry => 0,
            manual_review => 1,
        };
    }

    return {
        success       => 0,
        error         => 'Error printing on printer',
        id            => $print_job->printer,
        safe_to_retry => 1,
        }
        unless $cups_print_job_id;


    my $cups_print_job_data;
    try {
        $cups_print_job_data = $cups_printer->getJob($cups_print_job_id);
    };
    $cups_print_job_data ||= { id => $cups_print_job_id };
    $cups_print_job_data->{id} //= $cups_print_job_id;

    # Libki's Done state means the physical backend accepted the job. Do not
    # persist CUPS' transient "processing" state: this CUPS tier intentionally
    # purges completed job history, so polling that state would leave the staff
    # UI stuck forever after the job disappears from CUPS.
    my $updated = $print_job->update(
        {
            data       => $cups_print_job_data,
            status     => PRINT_STATUS_DONE,
            queued_on  => $c->now(),
            queued_to  => $cups_printer_name,
            updated_on => $c->now(),
        }
    );

    unless ($updated) {
        $log->error(
            "CUPS accepted print job $cups_print_job_id but Libki job " . $print_job->id . " could not be updated"
        );
        return {
            success       => 0,
            error         => 'CUPS accepted the job but Libki requires staff review',
            safe_to_retry => 0,
            manual_review => 1,
        };
    }

    $c->model('DB::Statistic')->create(
        {
            instance   => $c->instance,
            username   => $c->user ? $c->user->username : '',
            action     => 'PRINT_JOB_RELEASED',
            created_on => $c->now,
            session_id => $c->sessionid // '',
            info       => to_json(
                {
                    print_job_id => $print_job->id,
                }
            ),
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
