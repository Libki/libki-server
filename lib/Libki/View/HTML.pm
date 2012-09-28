package Libki::View::HTML;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,

    INCLUDE_PATH => [
        Libki->path_to( 'root', 'templates' ),
    ],
    
    # Set to 1 for detailed timer stats in your HTML as comments
    TIMER => 0,
    
    WRAPPER => 'wrapper.tt',
);

=head1 NAME

Libki::View::HTML - TT View for Libki

=head1 DESCRIPTION

TT View for Libki.

=head1 SEE ALSO

L<Libki>

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

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

1;
