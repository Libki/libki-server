package Libki::Controller::Metrics;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Encode qw(decode);

=head1 NAME

Libki::Controller::Metrics - Catalyst Controller for Prometheus Metrics

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 begin

=cut

sub begin : Private { }

=head2 end

=cut

sub end  : Private  { }

=head2 index

=cut

sub index : Path Args(0) {
    my ( $self, $c ) = @_;
    $c->prometheus->set( 'active_clients', $c->model('DB::Client')->search( { status => 'online' } )->count() );
    $c->prometheus->set( 'active_sessions', $c->model('DB::Session')->count() );

    my $res = $c->res;
    $res->content_type("text/plain");
    $res->output( $c->prometheus->format );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

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
