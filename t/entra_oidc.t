use strict;
use warnings;
use Test::More;
use lib 'lib';
use Libki::Auth::EntraConfig;
use OIDC::Client;
use OIDC::Client::Plugin;
use Crypt::PK::RSA;
use Crypt::JWT qw(encode_jwt);
use JSON qw(decode_json);
use Mojo::URL;
use Catalyst::Log;
my $log = Catalyst::Log->new(qw/error/);

# Ephemeral signing key and synthetic metadata: no network, tenant, or saved key.
my $key = Crypt::PK::RSA->new;
$key->generate_key(256,65537);
my $jwk = decode_json($key->export_key_jwk('public'));
$jwk->{kid}='ephemeral-test';
my $tenant='11111111-2222-4333-8444-555555555555';
my $id='aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
my (undef,$config) = Libki::Auth::EntraConfig->from_env({
    LIBKI_ENTRA_ENABLED=>1,LIBKI_ENTRA_TENANT_ID=>$tenant,
    LIBKI_ENTRA_CLIENT_ID=>$id,OIDC_ENTRA_SECRET=>'test-only',
});
my $issuer="https://login.microsoftonline.com/$tenant/v2.0";
my $client=OIDC::Client->new(log=>$log,
    config=>{%{$config->{provider}{ENTRA}},provider=>'ENTRA'},
    provider_metadata=>{issuer=>$issuer,authorize_url=>'https://identity.example.org/authorize'},
    kid_keys=>{keys=>[$jwk]},
);
sub token {
    my (%changes)=@_;
    encode_jwt(payload=>{iss=>$issuer,aud=>$id,sub=>'test-subject',iat=>time,exp=>time+3600,
        nonce=>'test-nonce',%changes},key=>$key,alg=>'RS256',extra_headers=>{kid=>'ephemeral-test'});
}
sub verify {
    $client->verify_jwt_token(token=>$_[0],expected_audience=>$id,expected_authorized_party=>$id,
        no_authorized_party_accepted=>1,expected_nonce=>'test-nonce',max_token_age=>600);
}
ok(verify(token()),'valid signed ID token accepted by actual OIDC dependency');
for my $case (
    ['wrong issuer',iss=>'https://identity.example.org/wrong'],
    ['wrong audience',aud=>'another-client'],
    ['wrong nonce',nonce=>'wrong'],
    ['expired token',exp=>time-120],
    ['old issue time',iat=>time-1000],
    ['wrong authorized party',azp=>'another-client'],
) {
    my ($label,@changes)=@$case;
    eval { verify(token(@changes)) };
    ok($@,"$label rejected");
}
my $bad=token(); my @parts=split /\./,$bad; substr($parts[2],0,1)=substr($parts[2],0,1) eq 'A'?'B':'A';
eval { verify(join('.',@parts)) };
ok($@,'bad signature rejected');
my $session={}; my $url;
my $plugin=OIDC::Client::Plugin->new(log=>$log,
    client=>$client,session=>$session,stash=>{},request_params=>{},request_headers=>{},
    base_url=>'https://staff.example.org/',current_url=>'https://staff.example.org/administration/login/entra',
    redirect=>sub {$url=shift},
);
$plugin->redirect_to_authorize(target_url=>'https://staff.example.org/administration/login/entra/complete');
my $query=Mojo::URL->new($url)->query;
is($query->param('code_challenge_method'),'S256','real authorize flow uses S256');
ok(length($query->param('nonce'))>=16,'real authorize flow generates nonce');
my $state=$query->param('state');
ok($session->{oidc_auth}{$state}{code_verifier},'PKCE verifier retained server-side');
$plugin->request_params->{state}='unknown';
eval {$plugin->get_token};
ok($@,'unknown callback state rejected before token exchange');
done_testing;
