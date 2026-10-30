use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Digest::SHA qw(hmac_sha256_hex);
use HTTP::Headers;
use Libki::ScreenViewer qw(config_from_env mint_token normalize_reason);
use Libki::Controller::Administration::API::ScreenViewer;

my $dir = tempdir(CLEANUP=>1);
for my $pair (['hmac','test-only-hmac-key-' x 3],['vnc','Example!']) {
    open my $f,'>',"$dir/$pair->[0]" or die $!;
    print $f $pair->[1]; close $f;
}
my %env=(LIBKI_VIEWER_ENABLED=>'true',LIBKI_VIEWER_INSTANCE=>'demo',LIBKI_VIEWER_ORIGIN=>'https://libki.example.org',
 LIBKI_VIEWER_CLIENT_NAME=>'demo.pc.example',LIBKI_VIEWER_HMAC_FILE=>"$dir/hmac",
 LIBKI_VIEWER_PASSWORD_FILE=>"$dir/vnc");
ok(!config_from_env({})->{enabled},'off by default');
my $config=config_from_env(\%env);
my $token=mint_token($config,'demo.pc.example',100);
like($token,qr/^demo\.pc\.example\.160\.[a-f0-9]{32}\.[a-f0-9]{64}$/,'dotted client token');
my ($payload,$signature)=$token=~/^(.*)\.([^.]+)$/;
is($signature,hmac_sha256_hex($payload,$config->{hmac_secret}),'correct signature');
eval { config_from_env({%env,LIBKI_VIEWER_ORIGIN=>'http://libki.example.org'}) };
ok($@,'reject HTTP configuration');
eval { mint_token($config,'other') };ok($@,'reject unknown client');
eval { normalize_reason('other') };ok($@,'reject unsupported reason');

{ package FakeRequest;
  sub method {$_[0]{method}} sub params {$_[0]{params}}
  sub headers {$_[0]{headers}} sub address {'192.0.2.20'}
  package FakeResponse;
  sub headers {$_[0]{headers}} sub status {$_[0]{status}=$_[1] if @_>1; $_[0]{status}}
  package FakeUser;
  sub instance {$_[0]{instance}} sub username {'demo-staff'} sub id {1}
  package FakeSession; sub user {bless {},'FakeUser'}
  package FakeClient; sub session {bless {},'FakeSession'}
  package FakeModel;
  sub find {bless {},'FakeClient'}
  sub create {die 'fixture write failure' if $_[0]{fail}; push @{$_[0]{writes}},$_[1]; 1}
  package FakeContext;
  sub user_exists {$_[0]{authenticated}} sub check_user_roles {$_[0]{admin}}
  sub user {$_[0]{user}} sub instance {$_[0]{instance}//'demo'}
  sub request {$_[0]{request}} sub response {$_[0]{response}}
  sub config {$_[0]{config}} sub model {$_[0]{models}{$_[1]}}
  sub now {'2026-01-01'} sub sessionid {'test-session'}
  sub stash {$_[0]{stash}=$_[1]} sub view {'JSON'} sub forward {1}
}
sub context {
 return bless {
  authenticated=>1,admin=>1,user=>bless({instance=>'demo'},'FakeUser'),
  config=>{'Libki::ScreenViewer'=>$config},
  request=>bless({method=>'POST',params=>{client=>'demo.pc.example',reason=>'patron_assistance'},
    headers=>HTTP::Headers->new(Origin=>'https://libki.example.org','X-Requested-With'=>'XMLHttpRequest')},'FakeRequest'),
  response=>bless({status=>200,headers=>HTTP::Headers->new},'FakeResponse'),
  models=>{map {$_=>bless({writes=>[]},'FakeModel')} qw(DB::Client DB::Message DB::Statistic)}
 },'FakeContext';
}
my $controller=Libki::Controller::Administration::API::ScreenViewer->new;
for my $case (
 ['anonymous',403,sub {$_[0]{authenticated}=0}],
 ['non-admin',403,sub {$_[0]{admin}=0}],
 ['different instance',403,sub {$_[0]{user}{instance}='other'}],
 ['other configured instance',404,sub {$_[0]{instance}='other';$_[0]{user}{instance}='other'}],
 ['GET',405,sub {$_[0]{request}{method}='GET'}],
 ['cross-origin',403,sub {$_[0]{request}{headers}->header(Origin=>'https://other.example')}],
 ['no custom header',403,sub {$_[0]{request}{headers}->remove_header('X-Requested-With')}],
 ['unknown workstation',404,sub {$_[0]{request}{params}{client}='other'}],
 ['unknown reason',400,sub {$_[0]{request}{params}{reason}='other'}],
 ['notice failure',503,sub {$_[0]{models}{'DB::Message'}{fail}=1}],
 ['audit failure',503,sub {$_[0]{models}{'DB::Statistic'}{fail}=1}],
) {
 my $c=context();$case->[2]->($c);$controller->token($c);
 is($c->response->status,$case->[1],$case->[0]);
 ok(!exists $c->{stash}{token},'failure issues no token');
}
my $c=context();$controller->token($c);
is($c->response->status,200,'valid request');
ok($c->{stash}{token},'issues token after notice and audit');
is(scalar @{$c->{models}{'DB::Message'}{writes}},1,'patron notice');
is(scalar @{$c->{models}{'DB::Statistic'}{writes}},1,'audit');
is($c->{stash}{mode},'view-only','view-only mode');
is($c->response->headers->header('Cache-Control'),'no-store, private','no caching');
done_testing();
