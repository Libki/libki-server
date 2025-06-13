package Libki::Controller::API::PrintStation::v1_0;

use Moose;
use namespace::autoclean;

use Image::Magick::Thumbnail::PDF qw(create_thumbnail);
use JSON;
use List::Util qw(none);
use File::Temp qw(tempfile tempdir);
use Libki::Utils::Printing;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::API::Client::v1_0 - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 auto

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $api_key  = $c->request->params->{'api_key'};
    my $username = $c->request->params->{username};
    my $password = $c->request->params->{password};

    my $instance = $c->instance;

    my $api_key_validated = Libki::Auth::validate_api_key(
        {
            context => $c,
            key     => $api_key,
            type    => 'PrintStation',
        }
    );

    unless ($api_key_validated) {
        delete $c->stash->{$_} for keys %{ $c->stash };
        $c->response->status(401);
        $c->stash(
            success => JSON::false,
            error   => "INVALID_API_KEY",
        );
        $c->forward( $c->view('JSON') );
        return;
    }

    my $EnableClientPasswordlessMode = $c->stash->{Settings}->{EnableClientPasswordlessMode};

    unless ( $EnableClientPasswordlessMode ) {
        my $auth = Libki::Auth::authenticate_user(
            {
                context  => $c,
                username => $username,
                password => $password,
                no_external_auth => 1,
            }
        );

        unless ( $auth->{success} ) {
            delete $c->stash->{$_} for keys %{ $c->stash };
            $c->response->status(401);
            $c->stash(
                success => JSON::false,
                error   => $auth->{error},
            );
            $c->forward( $c->view('JSON') );
            return;
        }

        my $user = $auth->{user};
        $c->stash( { user => $user } );
    } else {
        my $user = $c->model('DB::User')->find({ instance => $c->instance, username => $username });

        unless ( $user ) {
            delete $c->stash->{$_} for keys %{ $c->stash };
            $c->response->status(404);
            $c->stash(
                success => JSON::false,
                error   => 'BAD_LOGIN',
            );
            $c->forward( $c->view('JSON') );
            return;
        }

        $c->stash( { user => $user } );
    }
}

=head2 print_jobs

API to send list of unfinished print jobs to the PrintStation client for print management

When hit, this API will send the next queued print job to the Print Manager
and mark it as Pending in the queue, with the time it was set to Pending.

If the Pending job is not confirmed within 1 minute, libki_cron.pl will
reset the status so another Print Manager can try again.

=cut

sub print_jobs : Path('print_jobs') : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $username = $c->request->params->{username};
    my $user     = $c->stash->{user};

    my $jobs = $c->model('DB::PrintJob')->search(
        {
            instance => $instance,
            user_id  => $user->id,
            status   => Libki::Utils::Printing::PRINT_STATUS_HELD,
            type     => 'PrintManager',
        },
        {
            order_by => { -desc => 'id' }
        }
    );

    my $printers = $c->get_printer_configuration->{printers};

    my $print_jobs = [];
    while ( my $j = $jobs->next ) {
        my $cost = Libki::Utils::Printing::calculate_job_cost( $c, { print_job => $j } );

        push(
            @$print_jobs,
            {
                print_job_id  => $j->id,
                printer       => $j->printer,
                copies        => $j->copies,
                created_on    => $c->format_dt( { dt => $j->created_on, include_time => 1 } ),
                print_file_id => $j->print_file_id,
                pages         => $j->print_file->pages,
                cost          => $cost,
            }
        );
    }

    my $data = {
        printers   => $printers,
        print_jobs => $print_jobs,
    };

    $c->response->headers->content_type('application/json');
    $c->response->body( JSON::to_json($data) );
    $c->response->write();
}

=head2 print_preview

Returns the PDF of a given print job.
If the param 'type' is set to 'print_preview', the content
disposition will be so so the PDF loads in a web browser.

=cut

sub print_preview : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $id       = $c->request->params->{id};
    my $page     = $c->request->params->{page} || 1;
    my $username = $c->request->params->{username};

    my $print_job = $c->model('DB::PrintJob')->find(
        {
            instance => $instance,
            id       => $id,
            username => $username,
        }
    );

    if ($print_job) {
        my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );
        if ($print_file) {
            my $dir = tempdir( CLEANUP => 1 );
            my ( $fh, $filename ) = tempfile( DIR => $dir, SUFFIX => '.pdf' );
            print $fh $print_file->data;
            close($fh);

            my $image = create_thumbnail(
                $filename,
                $page,
                {
                    restriction => 350,
                    frame       => 2,
                    normalize   => 0,
                }
            );
            open( my $image_fh, '<:raw', $image );

            $c->response->body($image_fh);

            $c->response->content_type('image/png');
            $c->response->header( 'Content-Disposition', "inline; filename=$id.png" );
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

=head2 release_print_job

Sends the given print job to the actual print management backend.

=cut

sub release_print_job : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->request->params->{id};
    my $printer = $c->request->params->{printer};

    my $user = $c->stash->{user};

    my $data = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id => $id,
            printer      => $printer,
            user         => $user
        }
    );

    delete $c->stash->{$_} for keys %{ $c->stash };
    $c->stash($data);

    $c->forward( $c->view('JSON') );
}

=head2 cancel_print_job

Sends the given print job to the actual print management backend.

=cut

sub cancel_print_job : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->request->params->{id};

    my $user = $c->stash->{user};

    my $data = Libki::Utils::Printing::cancel( $c, $id, $user );

    delete $c->stash->{$_} for keys %{ $c->stash };
    $c->stash($data);

    $c->forward( $c->view('JSON') );
}

=head2 funds_available

Returns the patron's current account balance in Libki

=cut

sub funds_available : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $username = $c->request->params->{username};

    my $instance = $c->instance;

    my $user = $c->stash->{user};

    my $funds = $user->funds;

    delete $c->stash->{$_} for keys %{ $c->stash };
    $c->stash( funds => $funds );

    $c->forward( $c->view('JSON') );
}

=head2 settings

Returns the settings needded by the Libki Print Station

=cut

sub settings : Local : Args(0) {
    my ( $self, $c ) = @_;

    my %settings = (
        EnableClientPasswordlessMode => $c->stash->{Settings}->{EnableClientPasswordlessMode},
    );

    delete $c->stash->{$_} for keys %{ $c->stash };

    $c->stash(%settings);

    $c->forward( $c->view('JSON') );
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
