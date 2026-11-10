use strict;
use warnings;
use Test::More;
use HTTP::Headers;
use URI;
use lib 'lib';
use Libki::Controller::Administration::Login;
use Libki::Controller::Administration::Logout;
use Libki::Controller::Administration;
{
    package TestContext;
    sub new {
        bless {config=>{'Libki::Entra'=>{enabled=>1,tenant_id=>'11111111-2222-4333-8444-555555555555',staff_app_role=>'Libki.Staff',admin_app_role=>'Libki.Admin'}},
            stash=>{},session=>{},flash=>{},headers=>HTTP::Headers->new,
            method=>'GET',params=>{},logs=>[],events=>[]}, shift;
    }
    sub config { $_[0]{config} }
    sub stash { my $s=shift; @{$s->{stash}}{@_[grep {$_%2==0} 0..$#_]}=@_[grep {$_%2==1} 0..$#_] if @_; $s->{stash} }
    sub session { $_[0]{session} }
    sub flash { $_[0]{flash} }
    sub response { $_[0] } sub request { $_[0] } sub log { $_[0] }
    sub headers { $_[0]{headers} }
    sub method { $_[0]{method} } sub params { $_[0]{params} }
    sub address { '192.0.2.1' }
    sub status { $_[0]{status}=$_[1] if @_>1; $_[0]{status} }
    sub redirect { $_[0]{redirect}="$_[1]" }
    sub uri_for { URI->new('https://staff.example.org'.$_[1]) }
    sub controller { $_[0] } sub action_for { '/administration' }
    sub warn { push @{$_[0]{logs}},$_[1] } sub info { shift->warn(@_) } sub error { shift->warn(@_) }
    sub oidc { bless {c=>$_[0]}, 'TestOIDC' }
    sub authenticate { $_[0]{authenticate_calls}++; $_[0]{password_ok} }
    sub find_user { $_[0]{wrapper} }
    sub set_authenticated { die 'test failure' if $_[0]{fail_auth}; $_[0]{authenticated}=$_[1];push @{$_[0]{events}},'auth' }
    sub change_session_id { push @{$_[0]{events}},'rotate'; 'new-id' }
    sub _session_store_delegate { $_[0]{delegate}=$_[1] }
    sub sessionid { 'new-id' } sub instance { 'test-instance' }
    sub now { '2026-01-01 00:00:00' }
    sub model { bless {c=>$_[0]}, 'TestAudit' }
    sub logout { delete $_[0]{authenticated}; $_[0]{logged_out}=1 }
    sub delete_session { $_[0]{session}={}; $_[0]{deleted_session}=1 }
    sub user_exists { !!$_[0]{authenticated} }
    package TestOIDC;
    sub delete_stored_data { delete $_[0]{c}{identity}; $_[0]{c}{cleared}=1 }
    sub redirect_to_authorize { my ($s,%args)=@_; $s->{c}{authorize}=\%args }
    sub get_valid_identity { $_[0]{c}{identity} }
    package TestIdentity;
    sub claims { $_[0]{claims} }
    package TestAudit;
    sub create { $_[0]{c}{audit}=$_[1] }
}
my $login = Libki::Controller::Administration::Login->new(_app => 'Libki');
my $logout = Libki::Controller::Administration::Logout->new(_app => 'Libki');
my $c = TestContext->new;
$login->index($c);
like($c->{redirect},qr{/login/entra$},'enabled login starts Microsoft sign-in');
is($c->{headers}->header('Cache-Control'),'no-store','login is not cached');
$c=TestContext->new; $c->{config}{'Libki::Entra'}{enabled}=0;
$login->index($c);
is($c->{stash}{template},'administration/login.tt','disabled feature keeps local login');
ok(!$c->{redirect},'disabled feature does not redirect to Microsoft');
$c=TestContext->new; $c->{params}={username=>'localadmin',password=>'test-only'};$c->{password_ok}=1;
$login->emergency($c);
ok(!$c->{authenticate_calls},'GET credentials are not processed');
$c->{method}='POST';$login->emergency($c);
ok($c->{authenticate_calls},'local recovery uses normal authentication');
is($c->{session}{staff_auth_source},'Local account','recovery session is distinguished');
$c=TestContext->new;$c->{method}='POST';$c->{params}={username=>'entra-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',password=>'test-only'};
$login->emergency($c);
ok(!$c->{authenticate_calls},'shadow account cannot use password recovery route');
$c=TestContext->new;$c->{params}{target_url}='https://attacker.example/';
$login->entra($c);
is($c->{authorize}{target_url},'https://staff.example.org/administration/login/entra/complete','caller cannot choose redirect target');
$c=TestContext->new;$login->entra_complete($c);
is($c->{status},401,'completion without verified identity is denied');
sub identity { bless {claims=>{tid=>'11111111-2222-4333-8444-555555555555',oid=>'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',exp=>time+3600,roles=>['Libki.Staff'],@_}}, 'TestIdentity' }
$c=TestContext->new;$c->{identity}=identity(roles=>['unassigned']);$login->entra_complete($c);
is($c->{status},403,'verified but unassigned user is denied');
ok(!$c->{authenticated},'denied identity has no staff session');
$c=TestContext->new;$c->{identity}=identity(exp=>time-1);$login->entra_complete($c);
is($c->{status},401,'expired identity is denied');
{
    no warnings 'redefine';
    local *Libki::Auth::Entra::sync_user = sub { return bless {}, 'TestUser' };
    $c=TestContext->new;$c->{identity}=identity();$c->{wrapper}=bless {},'TestUser';
    $login->entra_complete($c);
    ok($c->{authenticated},'verified assigned identity establishes Catalyst authentication');
    is_deeply($c->{events},['rotate','auth'],'session rotates before authentication');
    ok(!$c->{identity},'provider identity is removed after completion');
    ok($c->{session}{staff_entra_expires_at}>time,'absolute identity expiry retained');
    is($c->{audit}{action},'ADMIN_LOGIN','staff login audited without tokens');
    $login->entra_complete($c);
    is($c->{status},401,'completion identity cannot be replayed');
    $c=TestContext->new;$c->{identity}=identity();$c->{wrapper}=bless {},'TestUser';$c->{fail_auth}=1;
    $login->entra_complete($c);
    is($c->{status},500,'authentication failure is handled');
    ok(!$c->{authenticated},'failed authentication leaves no new staff identity');
}
$c=TestContext->new;$c->{flash}{error_message}='private provider response';
$login->entra_error($c);
ok(!exists $c->{flash}{error_message},'raw provider error removed');
unlike(join(' ',@{$c->{logs}}),qr/private provider/,'raw provider error not logged');
$c=TestContext->new;$c->{session}={oidc=>{token=>'synthetic'},oidc_auth=>{pending=>1}};$c->{authenticated}=1;
$logout->index($c);
ok($c->{deleted_session} && !$c->{authenticated},'logout destroys authenticated session');
is_deeply($c->{session},{},'logout discards tokens and unfinished flows');
like($c->{redirect},qr{/signed-out$},'SSO logout does not immediately sign in again');
$c=TestContext->new;$c->{session}={staff_auth_source=>'Microsoft Entra ID',staff_entra_expires_at=>time-1};$c->{authenticated}=1;
# Controller identity check in auto expects distinct objects.
{
    no warnings 'redefine';
    local *TestContext::controller = sub { $_[1] ? 'login-controller' : 'administration-controller' };
    is(Libki::Controller::Administration->new(_app => 'Libki')->auto($c),0,'expired staff session stops protected action');
    ok($c->{deleted_session} && !$c->{authenticated},'expiry removes staff identity');
}
done_testing;
