use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::API::User;

ok( request('/administration/api/user')->is_success, 'Request should succeed' );
done_testing();
