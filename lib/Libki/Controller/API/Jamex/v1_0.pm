package Libki::Controller::API::Jamex::v1_0;

use Moose;
use namespace::autoclean;

use List::Util qw(none);
use JSON;

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

    my $api_key_validated = Libki::Auth::validate_api_key(
        {
            context => $c,
            key     => $api_key,
            type    => 'Jamex',
        }
    );

    unless ($api_key_validated) {
        delete $c->stash->{Settings};
        $c->response->status(401);
        $c->stash(
            success => JSON::false,
            error   => "INVALID_API_KEY",
        );
        $c->forward( $c->view('JSON') );
        return;
    }

    my $auth = Libki::Auth::authenticate_user(
        {
            context  => $c,
            username => $username,
            password => $password,
        }
    );

    unless ($auth->{success}) {
        delete $c->stash->{Settings};
        $c->response->status(401);
        $c->stash(
            success => JSON::false,
            error   => $auth->{error},
        );
        $c->forward( $c->view('JSON') );
        return;
    }
}

=head2 add_funds

=cut

sub add_funds : Path('add_funds') : Args(0) {
    my ( $self, $c ) = @_;

    my $username = $c->request->params->{username};

    my $instance = $c->instance;
    my $config   = $c->config->{instances}->{$instance} || $c->config;
    my $log      = $c->log();

    my $user = $c->model('DB::User')->find( { instance => $instance, username => $username } );

    my $now = $c->now();
}

=head2 print_jobs

API to send list of unfinished print jobs to the Jamex client for print management

When hit, this API will send the next queued print job to the Print Manager
and mark it as Pending in the queue, with the time it was set to Pending.

If the Pending job is not confirmed within 1 minute, libki_cron.pl will
reset the status so another Print Manager can try again.

=cut

sub print_jobs : Path('print_jobs') : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    my $username = $c->request->params->{username};
    my $user     = $c->model('DB::User')->find( { instance => $instance, username => $username } );

    my $jobs = $c->model('DB::PrintJob')->search(
        {
            instance => $instance,
            user_id  => $user->id,
            status   => { '!=' => Libki::Utils::Printing::PRINT_STATUS_DONE },
            type     => 'PrintManager',
        },
        {
            order_by => { -desc => 'id' }
        }
    );

    my $data = [];
    while ( my $j = $jobs->next ) {
        push(
            @$data,
            {
                print_job_id  => $j->id,
                copies        => $j->copies,
                created_on    => $j->created_on->iso8601,
                print_file_id => $j->print_file_id,
                pages         => $j->print_file->pages,
            }
        );
    }
    $c->stash( print_jobs => $data );

    $c->response->headers->content_type('application/json');
    $c->response->body( JSON::to_json( $data ) );
    $c->response->write();
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
