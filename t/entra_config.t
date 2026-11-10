use strict;
use warnings;
use Test::More;
use lib 'lib';
use Libki::Auth::EntraConfig;
my ($disabled, $empty) = Libki::Auth::EntraConfig->from_env({});
ok(!$disabled->{enabled}, 'SSO defaults off');
is_deeply($empty->{provider}, {}, 'disabled setup makes no provider');
my %env = (
    LIBKI_ENTRA_ENABLED => 1,
    LIBKI_ENTRA_TENANT_ID => '11111111-2222-4333-8444-555555555555',
    LIBKI_ENTRA_CLIENT_ID => 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    OIDC_ENTRA_SECRET => join('', 'test', '-only'),
);
for my $required (qw/LIBKI_ENTRA_TENANT_ID LIBKI_ENTRA_CLIENT_ID OIDC_ENTRA_SECRET/) {
    my %bad = %env; delete $bad{$required};
    eval { Libki::Auth::EntraConfig->from_env(\%bad) };
    like($@, qr/\Q$required\E is required/, "missing $required fails closed");
}
for my $id (qw/LIBKI_ENTRA_TENANT_ID LIBKI_ENTRA_CLIENT_ID LIBKI_ENTRA_ADMIN_GROUP_ID LIBKI_ENTRA_STAFF_GROUP_ID/) {
    eval { Libki::Auth::EntraConfig->from_env({%env, $id => 'invalid'}) };
    like($@, qr/\Q$id\E must be a GUID/, "invalid $id fails closed");
}
my ($config, $oidc) = Libki::Auth::EntraConfig->from_env(\%env);
my $p = $oidc->{provider}{ENTRA};
ok($config->{enabled}, 'explicit configuration enables SSO');
is($p->{scope}, 'openid profile email', 'no Graph or offline access requested');
is($p->{store_mode}, 'session', 'tokens stay in server-side session');
ok($p->{use_pkce}, 'PKCE enabled');
is($p->{pkce_code_challenge_method}, 'S256', 'PKCE S256');
like($p->{well_known_url}, qr{/\Q$env{LIBKI_ENTRA_TENANT_ID}\E/v2\.0/}, 'issuer discovery is tenant-specific');
is($p->{max_id_token_age}, 600, 'token issue-age is bounded');
done_testing;
