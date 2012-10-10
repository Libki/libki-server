use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::API::Client;

ok( request('/administration/api/client')->is_success, 'Request should succeed' );
done_testing();
