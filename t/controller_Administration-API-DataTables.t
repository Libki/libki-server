use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::API::DataTables;

ok( request('/administration/api/datatables')->is_success, 'Request should succeed' );
done_testing();
