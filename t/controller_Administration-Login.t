use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::Login;

ok( request('/administration/login')->is_success, 'Request should succeed' );
done_testing();
