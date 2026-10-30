use strict;
use warnings;
use Test::More;
use lib 'lib';
use Libki::Auth::Entra;
{
    package TestContext;
    sub new { bless {roles=>{}, user=>undef}, shift }
    sub instance { 'test-instance' }
    sub now { '2026-01-01 00:00:00' }
    sub model { my ($s,$name)=@_; return $s if $name eq 'DB'; bless {c=>$s,name=>$name}, 'TestRS' }
    sub txn_do { $_[1]->() }
    package TestUser;
    sub id { 1 }
    sub status { $_[0]{status} }
    sub creation_source { $_[0]{creation_source} }
    sub update { my ($s,$data)=@_; @{$s}{keys %$data}=values %$data; $s }
    package TestRole;
    sub id { $_[0]{id} }
    package TestRS;
    sub find {
        my ($s,$where)=@_;
        if ($s->{name} eq 'DB::User') {
            die 'wrong instance' unless $where->{instance} eq 'test-instance';
            return $s->{c}{user};
        }
        return bless {id=>$where->{role}}, 'TestRole';
    }
    sub create { my ($s,$data)=@_; $s->{c}{user}=bless {%$data}, 'TestUser' }
    sub find_or_create { $_[0]{c}{roles}{$_[1]{role_id}}=1 }
    sub search { $_[0]{filter}=$_[1]; $_[0] }
    sub delete { delete $_[0]{c}{roles}{$_[0]{filter}{role_id}} }
}
my $ctx = TestContext->new;
my $decision = {
    authorized=>1,username=>'entra-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    firstname=>'Example',lastname=>'Staff',libki_roles=>[qw/admin superadmin/],
};
my $u = Libki::Auth::Entra->sync_user($ctx,$decision);
is($u->{creation_source},'entra','new account belongs to Entra');
is($u->{instance},'test-instance','account scoped to instance');
ok(length($u->{password})>=48,'new account receives high-entropy random password');
is_deeply([sort keys %{$ctx->{roles}}],[qw/admin superadmin/],'administrator receives both roles');
Libki::Auth::Entra->sync_user($ctx,{%$decision,libki_roles=>['admin']});
is_deeply([keys %{$ctx->{roles}}],['admin'],'downgrade removes superadmin role');
$u->{status}='disabled';
eval { Libki::Auth::Entra->sync_user($ctx,$decision) };
like($@,qr/locally disabled/,'locally disabled identity cannot sign in');
is($u->{status},'disabled','disabled account is not re-enabled');
$u->{status}='enabled'; $u->{creation_source}='manual';
eval { Libki::Auth::Entra->sync_user($ctx,$decision) };
like($@,qr/non-Entra account/,'local account collision fails closed');
eval { Libki::Auth::Entra->sync_user($ctx,{authorized=>0}) };
like($@,qr/not authorized/,'unauthorized decision cannot provision');
done_testing;
