package Libki::Template::Plugin::LibkiDate;

use strict;
use warnings;

use Template::Plugin;
use base qw( Template::Plugin );

=head2 format

TT plugin to format dates as mm/dd/yyyy.
TODO: Set the format via a system setting.

=cut

sub format {
    my ( $self, $date ) = @_;
    my $dt = DateTime::Format::DateParse->parse_datetime($date);
    return $dt->strftime( '%m/%d/%Y' );
}

1;
