use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration;

ok( request('/administration')->is_success, 'Request should succeed' );
done_testing();
