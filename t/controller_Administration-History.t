use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::History;

ok( request('/administration/history')->is_success, 'Request should succeed' );
done_testing();
