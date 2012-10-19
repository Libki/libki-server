use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::API::Client::v1_0;

ok( request('/api/client/v1_0')->is_success, 'Request should succeed' );
done_testing();
