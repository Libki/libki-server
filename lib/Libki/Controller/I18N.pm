package Libki::Controller::I18N;
use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::ChangeLocale - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 changelocale

Change the locale if the desired locale exists, then send the user back to the page he was visiting.

=cut

sub changelocale : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $lang = scalar $c->req->param("lang");
    if($c->installed_languages()->{$lang}){
        $c->session->{lang} = $lang;
    }
    my $ref = $c->req->referer() || '/';
    $c->res->redirect($ref);
}

=head1 AUTHOR

Maxime Beaulieu <maxime.beaulieu@inlibro.com>

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
