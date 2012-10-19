use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::API::Client;

ok( request('/api/client')->is_success, 'Request should succeed' );
done_testing();
