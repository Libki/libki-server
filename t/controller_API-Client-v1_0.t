use Modern::Perl;
use Test::More;

use JSON;
use Data::Dumper;

use Catalyst::Test 'Libki';
use Libki::Controller::API::Client::v1_0;
use Libki::Utils::User;

my $c = Libki->new();

my $base = '/api/client/v1_0';
my $base_params
    = '?node=testClient&location=testLocation&type=testType&ipaddress=123.123.123&macaddress=00-B0-D0-63-C2-26&hostname=testHostname&version=1.0.0';

for my $s (
    'DefaultTimeAllowance',      'DefaultSessionTimeAllowance',
    'DefaultGuestTimeAllowance', 'DefaultGuestSessionTimeAllowance'
    )
{
    $c->model('DB::Setting')
        ->update_or_create( { instance => $c->instance, name => $s, value => 60 } );
}

$c->model('DB::Setting')->update_or_create( { instance => $c->instance, name => 'ClientBehavior', value => "FCFS+RES" } );

subtest 'Client registration' => sub {

# Test response for no action FIXME: Maybe we should return a 4xx here?
    my $res = request($base);
    ok( $res->is_success, 'Request should succeed' );
    is( $res->status_line,     '200 OK', 'Status line is 200 OK' );
    is( $res->decoded_content, '{}',     'Content is empty JSON' );

# Test basic client registration
    $res = request( $base . $base_params . '&node_name=TestClient&action=register_node' );
    ok( $res->is_success, 'Client registration succeeded' );
    my $json = decode_json( $res->decoded_content );
    is( $json->{status}, 'online', 'Registered client status is "online"' );

};

my $user1
    = Libki::Utils::User::create_or_update_user( $c, { username => "test1", password => "test1" } );
isa_ok( $user1, "Libki::Model::DB::User", "Got a user" );

my $user2
    = Libki::Utils::User::create_or_update_user( $c, { username => "test2", password => "test2" } );
isa_ok( $user2, "Libki::Model::DB::User", "Got another user" );

subtest 'Client login' => sub {

    # Test bad logins
    ## Bad username
    my $res
        = request( $base
            . $base_params
            . '&username=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&password=badpassword&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    my $json = decode_json( $res->decoded_content );
    is( $json->{error}, 'BAD_LOGIN', 'User was not authenticated' );

    ### No username
    $res = request( $base . $base_params . '&username=&password=badpassword&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{error}, 'BAD_LOGIN', 'User was not authenticated' );

    ### Bad password
    $res = request( $base . $base_params . '&username=test1&password=badpassword&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{error}, 'BAD_LOGIN', 'User was not authenticated' );

    ### No password
    $res = request( $base . $base_params . '&username=test1&password=&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{error}, 'BAD_LOGIN', 'User was not authenticated' );

    ## Test good credentials
    $res = request( $base . $base_params . '&username=test1&password=test1&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    print STDERR "STUFF: " . $res->decoded_content;
    $json = decode_json( $res->decoded_content );
    is( $json->{authenticated}, '1', 'User was authenticated' );

    ## Test duplicate login, should succeed
    $res = request( $base . $base_params . '&username=test1&password=test1&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{authenticated}, '1', 'User was authenticated' );

    ## Test login with another user while original user is logged in
    $res = request( $base . $base_params . '&username=test2&password=test2&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{authenticated}, '1', 'User was authenticated' );

    #TODO: Check the sessions table to ensure old session was removed and new session was created

    # Test logout
    ## Test logout when logged in
    $res = request( $base . $base_params . '&username=test2&password=test2&action=logout' );
    ok( $res->is_success, 'Client logout response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{logged_out}, '1', 'User was logged out' );

    #TODO: Check the sessions table to ensure session was removed

    ## Test logout when not logged in
    $res = request( $base . $base_params . '&username=test2&password=test2&action=logout' );
    ok( $res->is_success, 'Client logout response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{logged_out}, '0', 'Logged out' );
};

subtest 'Client guest login' => sub {
    my $setting = $c->model('DB::Setting')
        ->find_or_create( { instance => $c->instance, name => 'EnableGuestSelfRegistration', value => 1 } );
    my $original_value = $setting->value;
    $setting->update( { value => 1 } );

    # Do guest login
    my $res = request( $base . $base_params . '&createGuest=1&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    my $json = decode_json( $res->decoded_content );
    is( $json->{authenticated}, '1', 'User was authenticated' );
    ok( $json->{username}, 'Got guest username' );
    ok( $json->{password}, 'Got guest password' );
    my $username1 = $json->{username};

    # Do second guest login
    $res = request( $base . $base_params . '&createGuest=1&action=login' );
    ok( $res->is_success, 'Client login response succeeded' );
    $json = decode_json( $res->decoded_content );
    is( $json->{authenticated}, '1', 'User was authenticated' );
    ok( $json->{username}, 'Got guest username' );
    ok( $json->{password}, 'Got guest password' );
    my $username2 = $json->{username};

    isnt( $username1, $username2, "Got different guest users for each login" );

    $setting->update( { value => 0 } );
    $res = request( $base . $base_params . '&createGuest=1&action=login' );
    ok( !$res->is_success, 'Client login response failed' );
    $json = decode_json( $res->decoded_content );
    is( $json->{authenticated}, '0', 'User was not authenticated' );
    is( $json->{error}, 'GUEST_SELF_REG_NOT_ENABLED',
        "Error indicates guest self registration is not enabled" );
};

done_testing()
