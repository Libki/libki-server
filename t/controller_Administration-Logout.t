use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::Logout;

ok( request('/administration/logout')->is_success, 'Request should succeed' );
done_testing();
