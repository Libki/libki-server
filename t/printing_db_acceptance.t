use Modern::Perl;
use Test::More;
use Test::MockObject;
use DateTime;
use HTTP::Headers;
use JSON qw(from_json);
use Libki::Schema::DB;
use Libki::Utils::Printing;
use Libki::Controller::Administration::API::PrintJob;
use Libki::Controller::Administration::API::DataTables;
# Real schema/controller, synthetic in-memory data; network-disabled container.
# CUPS is mocked: this cannot establish physical output acceptance.
my $db=Libki::Schema::DB->connect('dbi:SQLite:dbname=:memory:');
# Serializer override loses the loader's nullable flag during deploy only.
$db->source('PrintJob')->column_info('data')->{is_nullable}=1;
$db->deploy;
my $now=DateTime->new(year=>2026,month=>10,day=>28,hour=>12);
my $user=$db->resultset('User')->create({instance=>'ACCEPTANCE',username=>'synthetic-patron',password=>'unused',status=>'enabled',created_on=>$now,updated_on=>$now});
my $params={}; my $stash={}; my $http=200; my $is_admin=1; my $method='POST';
my $headers=HTTP::Headers->new('X-Requested-With'=>'XMLHttpRequest');
my $config={staff_print_release=>'enabled',printers=>{}};
for my $loc ('Main','Genealogy') { for my $mode ('bw','color') {
 $config->{printers}{lc($loc).'-'.$mode}={cost_per_page=>$mode eq 'bw'?0.15:0.35,locations=>['CPL '.$loc],public_name=>$loc.' '.$mode,release_location=>$loc.' desk'};
}}
my $req=Test::MockObject->new;
$req->mock(params=>sub{$params});$req->mock(param=>sub{$params->{$_[1]}});
$req->mock(method=>sub{$method});$req->mock(headers=>sub{$headers});
my $res=Test::MockObject->new;$res->mock(status=>sub{$http=$_[1] if @_>1;return $http});
my $log=Test::MockObject->new;for my $m(qw(info debug error warn)){$log->mock($m,sub{})}
my $c=Test::MockObject->new;
$c->mock(instance=>sub{'ACCEPTANCE'});$c->mock(now=>sub{$now});$c->mock(user=>sub{$user});
$c->mock(sessionid=>sub{'synthetic-session'});$c->mock(setting=>sub{''});$c->mock(log=>sub{$log});
$c->mock(check_user_roles=>sub{$is_admin});$c->mock(assert_user_roles=>sub{die 'ACCESS_DENIED' unless $is_admin});
$c->mock(request=>sub{$req});$c->mock(response=>sub{$res});$c->mock(get_printer_configuration=>sub{$config});
$c->mock(model=>sub{my $name=$_[1];return $db if $name eq 'DB';$name=~s/^DB:://;return $db->resultset($name)});
$c->mock(stash=>sub{shift;if(@_){my %v=@_==1?%{$_[0]}:@_;%$stash=(%$stash,%v)}return $stash});
$c->mock(view=>sub{'JSON'});$c->mock(forward=>sub{});$c->mock(format_dt=>sub{$_[1]{dt}->iso8601});
my $controller=Libki::Controller::Administration::API::PrintJob->new;
my $tables=Libki::Controller::Administration::API::DataTables->new;
my $backend='accept';my @submissions;
{ no warnings 'redefine';
 *Libki::Utils::Printing::cups_setup=sub{die 'REAL CUPS FORBIDDEN'};
 *Libki::Utils::Printing::release_for_cups=sub{
  my ($ctx,$data)=@_;my $job=$data->{print_job};
  push @submissions,{id=>$job->id,copies=>$job->copies,printer=>$job->printer};
  return {success=>0,error=>'SIMULATED_PRE_SUBMIT_FAILURE',safe_to_retry=>1} if $backend eq 'fail';
  return {success=>0,error=>'SIMULATED_UNCERTAIN_ACCEPTANCE',safe_to_retry=>0,manual_review=>1} if $backend eq 'uncertain';
  $job->update({status=>'Done',queued_to=>$job->printer,queued_on=>$now});
  return {success=>1,message=>'Mock backend accepted'};
 };
}
my $seq=0;
sub fixture {
 my (%v)=@_;my $n=++$seq;my $loc=$v{location}//'Main';my $inst=$v{instance}//'ACCEPTANCE';
 my $file=$db->resultset('PrintFile')->create({instance=>$inst,filename=>"synthetic-$n.pdf",content_type=>'application/pdf',data=>'synthetic-not-a-real-pdf',pages=>$v{pages}//2,client_name=>"SYNTHETIC-$loc",client_location=>"CPL $loc",username=>'synthetic-patron',user_id=>$user->id,created_on=>$now,updated_on=>$now});
 return $db->resultset('PrintJob')->create({instance=>$inst,type=>'cups',status=>$v{status}//'Held',copies=>1,printer=>lc($loc).'-'.($v{mode}//'color'),user_id=>$user->id,print_file_id=>$file->id,created_on=>$now->clone->add(seconds=>$n),updated_on=>$now});
}
sub request {my ($action,%v)=@_;$params={%v};$stash={};$http=200;$controller->$action($c);return {%$stash}}
sub refresh {$_[0]->discard_changes;return $_[0]}
subtest '408: all four queues, quantities and guarded cash controller' => sub {
 for my $loc ('Main','Genealogy') {for my $mode ('bw','color') {
  my $job=fixture(location=>$loc,mode=>$mode);
  for my $copies (1,5,16,99) {
   my $p=Libki::Utils::Printing::build_release_preview($c,{print_job_id=>$job->id,copies=>$copies});
   ok($p->{success},"$loc $mode $copies quote");is($p->{total_pages},2*$copies,'pages multiplied');
   is($p->{amount_due},sprintf('%.2f',2*$copies*($mode eq 'bw'?0.15:0.35)),'correct amount');
   is(refresh($job)->copies,1,'preview immutable');
  }
  my %v=(id=>$job->id,copies=>5,expected_amount=>$mode eq 'bw'?'1.50':'3.50',cash_received=>1);
  my $before=@submissions;
  is(request('release',%v,cash_received=>0)->{error},'CASH_PAYMENT_NOT_CONFIRMED','cash gate');
  $method='GET';is(request('release',%v)->{error},'METHOD_NOT_ALLOWED','GET blocked');$method='POST';
  $headers->remove_header('X-Requested-With');is(request('release',%v)->{error},'INVALID_RELEASE_REQUEST','XHR gate');
  $headers->header('X-Requested-With'=>'XMLHttpRequest');
  is(request('release',%v,expected_amount=>'0.01')->{error},'PRINT_COST_CHANGED','stale price blocked');
  is(scalar @submissions,$before,'rejections never submit');
  ok(request('release',%v)->{success},'confirmed release');ok(!request('release',%v)->{success},'duplicate blocked');
  is(scalar @submissions,$before+1,'one backend invocation');is(refresh($job)->copies,5,'quantity persisted');
 }}
};
subtest '410: actual DB pending/history/location/search/sort/pagination' => sub {
 $db->resultset('Statistic')->delete_all;$db->resultset('PrintJob')->delete_all;
 for my $loc ('Main','Genealogy') {for my $status(qw(Held Pending InProgress Done Canceled)){fixture(location=>$loc,status=>$status)}}
 fixture(instance=>'OTHER',status=>'Held');
 my $query=sub{my %v=@_;$params={queue_view=>'pending',length=>100,start=>0,'order[0][column]'=>8,'order[0][dir]'=>'desc',%v};$stash={};$tables->prints($c);return {%$stash}};
 my $r=$query->();is($r->{recordsTotal},10,'instance scoped total');is($r->{recordsFiltered},6,'six pending/attention states');
 ok(!grep({$_->{'1'} eq 'Done'||$_->{'1'} eq 'Canceled'} @{$r->{data}}),'terminal jobs excluded');
 my @ids=map{$_->{DT_RowId}}@{$r->{data}};is_deeply(\@ids,[sort{$b<=>$a}@ids],'newest first');
 $r=$query->(queue_view=>'all');is($r->{recordsFiltered},10,'history retained');
 $r=$query->(queue_view=>'all','search[value]'=>'Done',location_filter=>'CPL Genealogy');
 is($r->{recordsFiltered},1,'history search + Genealogy');is($r->{data}[0]{'1'},'Done','completed row found');
 $r=$query->(location_filter=>'CPL Main');is($r->{recordsFiltered},3,'Main pending only');
 is_deeply($query->(location_filter=>'CPL Main'),$r,'refresh consistent');
 $r=$query->(length=>2,start=>2);is(scalar @{$r->{data}},2,'pagination');is($r->{recordsFiltered},6,'count stable');
 is($query->('search[value]'=>'absent')->{recordsFiltered},0,'empty search');
};
subtest '409: 16 copies and accepted/failed/uncertain replay on all queues' => sub {
 for my $loc ('Main','Genealogy') {for my $mode ('bw','color') {for my $case ('accept','fail','uncertain') {
  $backend=$case;my $source=fixture(location=>$loc,mode=>$mode,status=>'Done');
  my %original=refresh($source)->get_columns;my $before=@submissions;my $before_jobs=$db->resultset('PrintJob')->count;
  my %v=(id=>$source->id,copies=>16,cash_received=>1,expected_amount=>$mode eq 'bw'?'4.80':'11.20',request_id=>sprintf('acceptance-20261028-%08d',$source->id));
  my $result=request('reprint',%v);my $newid=$result->{reprint_job_id};ok($newid,"$loc $mode $case new job");
  my $new=$db->resultset('PrintJob')->find($newid);is($new->copies,16,'16 copies in one job');
  is($new->printer,$source->printer,'routing preserved');is($db->resultset('PrintJob')->count,$before_jobs+1,'one new job');
  is_deeply({refresh($source)->get_columns},\%original,'original immutable');
  if($case eq 'accept'){
   ok($result->{success},'accepted');ok(request('reprint',%v)->{success},'accepted replay succeeds');
   is(scalar @submissions,$before+1,'replay not resubmitted');
  }elsif($case eq 'fail'){
   ok(!$result->{success},'failure reported');is(refresh($new)->status,'Held','known failure restored Held');
   $backend='accept';my $retry=request('reprint',%v);ok($retry->{success},'safe retry succeeds');is($retry->{reprint_job_id},$newid,'same retry job');
   is(scalar @submissions,$before+2,'one failed attempt then one accepted');
  }else{
   ok(!$result->{success},'uncertain reported');is(refresh($new)->status,'Pending','uncertain stays non-releasable');
   ok(!request('reprint',%v)->{success},'uncertain replay blocked');is(scalar @submissions,$before+1,'no second uncertain submission');
  }
  is($db->resultset('PrintJob')->count,$before_jobs+1,'no duplicate job after replay');
  my @cash=grep {(eval {from_json($_->info)->{print_job_id}}//0)==$newid}
      $db->resultset('Statistic')->search({action=>'PRINT_PAYMENT_CASH'})->all;
  my @void=grep {(eval {from_json($_->info)->{print_job_id}}//0)==$newid}
      $db->resultset('Statistic')->search({action=>'PRINT_PAYMENT_CASH_VOID'})->all;
  is(scalar(@cash),$case eq 'fail'?2:1,'cash audited once per claimed attempt');
  is(scalar(@void),$case eq 'fail'?1:0,'only known failure compensated');
  my $net=0;$net+=from_json($_->info)->{amount} for @cash;
  $net-=from_json($_->info)->{amount} for @void;
  is(sprintf('%.2f',$net),$v{expected_amount},'one net cash charge');
  is($db->resultset('Transaction')->count,0,'cash never debits patron account');
 }}}
};
done_testing;
