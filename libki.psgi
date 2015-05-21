use strict;
use warnings;

use Libki;

my $app = Libki->apply_default_middlewares(Libki->psgi_app);

