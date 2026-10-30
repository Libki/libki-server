use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;

use Libki::Auth::Entra;

my $tenant = '11111111-2222-4333-8444-555555555555';
my $oid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
my $other_tenant = '99999999-8888-4777-8666-555555555555';

my $config = {
    tenant_id     => $tenant,
    admin_app_role => 'Libki.Admin',
    staff_app_role => 'Libki.Staff',
};

sub decision {
    my (%claims) = @_;
    return Libki::Auth::Entra->authorization_from_claims(
        {
            tid => $tenant,
            oid => $oid,
            %claims,
        },
        $config,
    );
}

is(
    decision( tid => $other_tenant, roles => ['Libki.Admin'] )->{reason},
    'tenant_mismatch',
    'a token from another tenant is denied',
);

is(
    Libki::Auth::Entra->authorization_from_claims(
        { tid => $tenant, roles => ['Libki.Admin'] },
        $config,
    )->{reason},
    'missing_object_id',
    'an identity without an Entra object ID is denied',
);

is(
    decision( roles => ['Some.Other.Role'] )->{reason},
    'not_assigned',
    'an authenticated but unassigned identity is denied',
);

my $staff = decision(
    roles              => ['Libki.Staff'],
    name               => "  Library\x00 Staff  ",
    preferred_username => 'library.staff@example.gov',
);
ok($staff->{authorized}, 'the staff app role is authorized');
is($staff->{role_level}, 'staff', 'the staff app role receives staff scope');
is_deeply($staff->{libki_roles}, ['admin'], 'staff receives the normal Libki administration role');
is($staff->{authorization_source}, 'app_role', 'staff authorization records the app-role source');
is($staff->{display_name}, 'Library Staff', 'display names are normalized before entering the session');
is($staff->{email}, 'library.staff@example.gov', 'preferred username supplies email when the email claim is absent');

my $admin = decision(
    roles  => ['Libki.Admin'],
    name   => 'Information Technology',
    email  => 'it@example.gov',
);
ok($admin->{authorized}, 'the administrator app role is authorized');
is($admin->{role_level}, 'admin', 'the administrator app role receives administrator scope');
is_deeply($admin->{libki_roles}, [qw/admin superadmin/], 'administrator receives both Libki roles');

is($staff->{username}, "entra-$oid", 'the shadow username is stable and based on the immutable object ID');
is(
    decision( roles => ['Libki.Staff'], preferred_username => 'renamed@example.gov' )->{username},
    $staff->{username},
    'changing an email address does not change the shadow username',
);

my $admin_group = '12345678-9abc-67de-8f01-23456789abcd';
my $group_decision = Libki::Auth::Entra->authorization_from_claims(
    {
        tid    => $tenant,
        oid    => $oid,
        groups => [$admin_group],
    },
    {
        %{$config},
        admin_group_id => $admin_group,
    },
);
ok($group_decision->{authorized}, 'configured group fallback accepts an arbitrary valid Entra GUID');
is($group_decision->{authorization_source}, 'group', 'group fallback is identified in the audit decision');

my $overage = Libki::Auth::Entra->authorization_from_claims(
    {
        tid          => $tenant,
        oid          => $oid,
        _claim_names => { groups => 'src1' },
    },
    {
        %{$config},
        staff_group_id => 'abcd1234-5678-4abc-8def-1234567890ab',
    },
);
is($overage->{reason}, 'group_overage', 'group overage is denied instead of silently broadening access');

ok(Libki::Auth::Entra->is_shadow_username("entra-$oid"), 'valid Entra shadow username is recognized');
ok(!Libki::Auth::Entra->is_shadow_username('libkiadmin'), 'local account is not mistaken for an Entra shadow account');

done_testing;
