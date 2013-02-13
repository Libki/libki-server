use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::API::Public::Datatables;

ok( request('/api/public/datatables')->is_success, 'Request should succeed' );
done_testing();
