use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::jqGrid;

ok( request('/administration/jqgrid')->is_success, 'Request should succeed' );
done_testing();
