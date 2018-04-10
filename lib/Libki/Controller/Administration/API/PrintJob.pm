package Libki::Controller::Administration::API::PrintJob;
use Moose;
use namespace::autoclean;

use JSON qw( to_json from_json );
use Storable qw( thaw );
use HTTP::Request::Common;
use Net::OAuth2::AccessToken;
use Net::Google::DataAPI::Auth::OAuth2;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::Print - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 cancel

=cut

sub cancel : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $id = $c->request->params->{id};

    my $print_job = $c->model('DB::PrintJob')->find( { id => $id, instance => $instance } );

    if ($print_job) {
        $print_job->set_column( 'status', 'Canceled' );
        my $success = $print_job->update() ? 1 : 0;
        $c->stash( success => $success );
    }
    else {
        $c->stash( success => 0, error => 'PRINT_JOB_NOT_FOUND' );
    }

    $c->forward( $c->view('JSON') );
}

=head2 google_cloud_authenticate

=cut

sub google_cloud_authenticate : Private : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $conf = $c->config->{instances}->{$instance} || $c->config;
    my $printers_conf = $conf->{printers};

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

    my $auth_response = $token->profile->request_auth( $token,
        GET => 'https://www.google.com/cloudprint/search' );

    $c->stash->{google_cloud_print_token} = $token;
}

=head2 release

=cut

sub release : Local : Args(0) {
    my ( $self, $c ) = @_;

    $self->google_cloud_authenticate($c);
    my $token = $c->stash->{google_cloud_print_token};
    delete $c->stash->{google_cloud_print_token};

    my $instance = $c->instance;

    my $id = $c->request->params->{id};

    my $print_job = $c->model('DB::PrintJob')->find( { id => $id, instance => $instance } );

    if ($print_job) {
        my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );
        if ($print_file) {
            my $conf          = $c->config->{instances}->{$instance} || $c->config;
            my $printers_conf = $conf->{printers};
            my $printers      = $printers_conf->{printer};
            my $printer       = $printers->{ $print_job->printer };

            if ($printer) {
                my $filename = $print_file->filename;
                my $content  = $print_file->data;

                my $ticket = { "version" => "1.0", "print" => {}, };

                my $ticket_conf = $printer->{ticket};
                foreach my $key ( keys %$ticket_conf ) {
                    my $data = from_json( $ticket_conf->{$key} );
                    $ticket->{print}->{$key} = $data;
                }

                my $ticket_json = to_json($ticket);

                my $request = POST 'https://www.google.com/cloudprint/submit',
                    Content_Type => 'form-data',
                    Content      => [
                    printerid => $printer->{google_cloud_id},
                    content   => [ undef, $filename, Content => $content ],
                    title     => $filename,
                    ticket    => $ticket_json,
                    ];

                my $response = $token->profile->request_auth( $token, $request );

                my $json = JSON::from_json( $response->decoded_content );

                $print_job->set_column( 'data',   to_json($json) );   # Re-encode to clean up syntax
                $print_job->set_column( 'status', 'Queued' );
                $print_job->update();

                $c->stash( success => 1, message => $json->{message} );
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
    else {
        $c->stash( success => 0, error => 'Print Job Not Found', id => $id );
    }

    $c->forward( $c->view('JSON') );
}

sub view : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $id = $c->request->params->{id};

    my $print_job = $c->model('DB::PrintJob')->find($id);

    if ($print_job) {
        my $print_file = $c->model('DB::PrintFile')->find( $print_job->print_file_id );
        if ($print_file) {
            my $filename = $print_file->filename;

            $c->response->body( $print_file->data );
            $c->response->content_type('application/pdf');
            $c->response->header( 'Content-Disposition', "inline; filename=$filename" );
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
