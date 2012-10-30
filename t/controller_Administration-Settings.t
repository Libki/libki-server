use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Libki';
use Libki::Controller::Administration::Settings;

ok( request('/administration/settings')->is_success, 'Request should succeed' );
done_testing();
