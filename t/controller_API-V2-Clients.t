use strict;
use warnings;

use Test::More;
use JSON qw(encode_json decode_json);

use Catalyst::Test 'Libki';
use HTTP::Request::Common;

# --------------------------------------------------
# Basic endpoint availability
# --------------------------------------------------

my $response;

$response = request('/api/v2/clients');
ok(
    $response->is_success || $response->code == 403,
    'GET /api/v2/clients responds'
);

$response = request('/api/v2/clients/1');
ok(
    $response->is_success
        || $response->code == 403
        || $response->code == 404,
    'GET /api/v2/clients/1 responds'
);

# --------------------------------------------------
# Invalid client
# --------------------------------------------------

$response = request('/api/v2/clients/999999');

ok(
    $response->code == 404
        || $response->code == 403,
    'Invalid client returns 404 or auth failure'
);

# --------------------------------------------------
# Invalid route
# --------------------------------------------------

$response = request('/api/v2/clients/invalid/route');

is(
    $response->code,
    404,
    'Invalid nested route returns 404'
);

# --------------------------------------------------
# JSON content type
# --------------------------------------------------

$response = request('/api/v2/clients');

if ( $response->is_success ) {

    like(
        $response->header('Content-Type'),
        qr/application\/json/,
        'Clients endpoint returns JSON'
    );

    my $data = eval {
        decode_json( $response->content );
    };

    ok(
        !$@,
        'Clients endpoint returns valid JSON'
    );

    ok(
        ref($data) eq 'ARRAY',
        'Clients endpoint returns array'
    );
}

# --------------------------------------------------
# Client detail JSON structure
# --------------------------------------------------

$response = request('/api/v2/clients/1');

if ( $response->is_success ) {

    my $data = eval {
        decode_json( $response->content );
    };

    ok(
        !$@,
        'Client detail returns valid JSON'
    );

    ok(
        exists $data->{id},
        'Client has id field'
    );

    ok(
        exists $data->{name},
        'Client has name field'
    );

    ok(
        exists $data->{status},
        'Client has status field'
    );

    ok(
        exists $data->{location_id},
        'Client has location_id field'
    );

    ok(
        exists $data->{location_hierarchy},
        'Client has location_hierarchy field'
    );

    ok(
        ref($data->{location_hierarchy}) eq 'ARRAY',
        'location_hierarchy is array'
    );
}

# --------------------------------------------------
# POST create client
# --------------------------------------------------

$response = request(
    POST '/api/v2/clients',
    Content_Type => 'application/json',
    Content => encode_json({
        name        => 'TEST_API_CLIENT',
        location_id => undef,
        status      => 'online',
        type        => 'pc',
    })
);

ok(
    $response->is_success
        || $response->code == 201
        || $response->code == 403,
    'POST /api/v2/clients responds'
);

# --------------------------------------------------
# Unsupported method
# --------------------------------------------------

$response = request(
    HTTP::Request->new(
        PATCH => '/api/v2/clients/1'
    )
);

ok(
    $response->code == 405
        || $response->code == 404,
    'Unsupported method rejected'
);

done_testing();