package Libki::Template::Plugin::LibkiDate;

use strict;
use warnings;

use Template::Plugin;
use base qw( Template::Plugin );

sub format {
    my ( $self, $date ) = @_;
    my $dt = DateTime::Format::DateParse->parse_datetime($date);
    return $dt->strftime( '%m/%d/%Y' );
}

1;