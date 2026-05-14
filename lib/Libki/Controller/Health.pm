package Libki::Controller::Health;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

=head1 NAME

Libki::Controller::Heatlh - Health check controller for Libki

=head1 DESCRIPTION

Provides lightweight endpoints to check liveliness and readiness

=head1 METHODS

=head2 live

GET /health/live

=cut

sub live : Path('/health/live') Args(0) {
    my ( $self, $c ) = @_;

    $self->status_ok($c, entity => {
        status => 'ok',
    });
}

=head2 ready

GET /health/ready

=cut

sub ready : Path('/health/ready') Args(0) {
    my ( $self, $c ) = @_;

    my $schema = $c->model('DB')->schema;

    my $db_ok = eval {
        $schema->storage->dbh->ping;
        1;
    };

    unless ($db_ok) {
        $c->response->status(503);

        return $self->status_service_unavailable(
            $c,
            message => 'database unavailable',
        );
    }

    my $active_clients = eval {
        $schema->resultset('Client')->search({
            status => 'online',
        })->count;
    };

    if ($@) {
        $c->response->status(503);

        return $self->status_service_unavailable(
            $c,
            message => 'database query failed',
        );
    }

    $self->status_ok($c, entity => {
        status         => 'ok',
        database       => 'ok',
        active_clients => $active_clients + 0,
        timestamp      => DateTime->now->iso8601,
    });
}

=head1 AUTHOR

Ian Walls <ian@bywatersolutions.com>

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