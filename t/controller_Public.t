use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Public;

ok( request('/public')->is_success, 'Request should succeed' );
done_testing();
