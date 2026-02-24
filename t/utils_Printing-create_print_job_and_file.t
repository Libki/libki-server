use Modern::Perl;
use Test::More;
use Test::MockObject;

use JSON qw(to_json from_json);

use Libki::Utils::Printing;

# Helper to build a mock $c context object
sub build_mock_c {
    my (%opts) = @_;

    # Track stuff
    my @created_stats;
    my @created_files;
    my @created_jobs;

    my $stat_rs = Test::MockObject->new();
    $stat_rs->mock( 'create', sub { shift; push @created_stats, shift; return 1; } );

    my $file_rs = Test::MockObject->new();
    $file_rs->mock( 'create', sub {
        shift;
        my $data = shift;
        my $f = Test::MockObject->new();
        $f->mock( 'id', sub { return 101; } );
        $f->mock( 'type', sub { return $data->{content_type}; } );
        $f->mock( 'filename', sub { return $data->{filename}; } );
        push @created_files, $data;
        return $f;
    });

    my $job_rs = Test::MockObject->new();
    $job_rs->mock( 'create', sub {
        shift;
        my $data = shift;
        my $j = Test::MockObject->new();
        $j->mock( 'id', sub { return 501; } );
        push @created_jobs, $data;
        return $j;
    });

    my $db_model = Test::MockObject->new();
    $db_model->mock( 'txn_do', sub { my ( $self, $code ) = @_; $code->(); } );

    my $user = Test::MockObject->new();
    $user->mock( 'id', sub { return 1; } );
    $user->mock( 'username', sub { return 'testuser'; } );

    my $client_rs = Test::MockObject->new();
    $client_rs->mock( 'single', sub { return undef; } );

    my $user_rs = Test::MockObject->new();
    $user_rs->mock( 'single', sub { return $user; } );

    my $c = Test::MockObject->new();
    $c->mock( 'instance',  sub { return 'TEST'; } );
    $c->mock( 'now',       sub { return '2026-02-13 12:00:00'; } );
    $c->mock( 'sessionid', sub { return 'test-session'; } );
    $c->mock( 'user',      sub { return $user; } );
    $c->mock( 'stash',     sub { return; } );
    $c->mock( 'get_printer_configuration', sub {
        return { printers => { printer1 => { type => 'PrintManager', cost_per_page => 0.10 } } };
    });
    $c->mock( 'model', sub {
        my ( $self, $name ) = @_;
        return $stat_rs if $name eq 'DB::Statistic';
        return $file_rs if $name eq 'DB::PrintFile';
        return $job_rs  if $name eq 'DB::PrintJob';
        return $client_rs if $name eq 'DB::Client';
        return $user_rs if $name eq 'DB::User';
        return $db_model if $name eq 'DB';
        return undef;
    });

    return ( $c, \@created_stats, \@created_files, \@created_jobs );
}

subtest 'Create print job logs statistic' => sub {
    my ( $c, $stats, $files, $jobs ) = build_mock_c();

    my $mock_file = Test::MockObject->new();
    $mock_file->mock( 'decoded_slurp', sub { return 'fake-data'; } );
    $mock_file->mock( 'filename', sub { return 'test.txt'; } );
    $mock_file->mock( 'type',     sub { return 'text/plain'; } );

    my $user_obj = Test::MockObject->new();
    $user_obj->mock( 'id',       sub { return 1; } );
    $user_obj->mock( 'username', sub { return 'testuser'; } );

    my $result = Libki::Utils::Printing::create_print_job_and_file( $c, {
        print_file   => $mock_file,
        printer_id   => 'printer1',
        user         => $user_obj,
        username     => 'testuser',
        client_name  => 'clientA',
        copies       => 2,
    });

    is( scalar @$jobs, 1, 'Print job created' );
    is( scalar @$stats, 1, 'One statistic created' );
    is( $stats->[0]->{action}, 'PRINT_JOB_CREATED', 'Statistic is PRINT_JOB_CREATED' );
    
    my $info = from_json($stats->[0]->{info});
    is( $info->{print_job_id}, 501, 'Correct job ID in stat info' );
    is( $info->{printer}, 'printer1', 'Correct printer name in stat info' );
    is( $info->{copies}, 2, 'Correct copies in stat info' );
    is( $info->{filename}, 'test.txt', 'Correct filename in stat info' );
};

done_testing();
