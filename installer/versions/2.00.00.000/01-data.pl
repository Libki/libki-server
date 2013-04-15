my $role_rs = $schema->resultset('Role');

$role_rs->create(
    {
        'id'   => 1,
        'role' => 'user',
    }
);

$role_rs->create(
    {
        'id'   => 2,
        'role' => 'admin',
    }
);

$role_rs->create(
    {
        'id'   => 3,
        'role' => 'superadmin',
    }
);

my $setting_rs = $schema->resultset('Setting');

$setting_rs->create( { 'name' => 'ClientBehavior',          'value' => 'FCFS+RES' } );
$setting_rs->create( { 'name' => 'CurrentGuestNumber',      'value' => '0' } );
$setting_rs->create( { 'name' => 'DefaultTimeAllowance',    'value' => '45' } );
$setting_rs->create( { 'name' => 'PostCrashTimeout',        'value' => '5' } );
$setting_rs->create( { 'name' => 'ReservationShowUsername', 'value' => '0' } );
$setting_rs->create( { 'name' => 'ReservationTimeout',      'value' => '15' } );
$setting_rs->create( { 'name' => 'ThirdPartyURL',           'value' => '' } );

