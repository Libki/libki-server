use Modern::Perl;
use Test::More;
use Test::MockObject;

use JSON qw(to_json);

use Libki::Utils::Printing;

# Helper to build a mock $c context object
sub build_mock_c {
    my (%opts) = @_;

    # Mock log object
    my $log = Test::MockObject->new();
    $log->mock( 'info',  sub { } );
    $log->mock( 'debug', sub { } );
    $log->mock( 'error', sub { } );

    # Track statistics created
    my @created_statistics;
    my $stat_rs = Test::MockObject->new();
    $stat_rs->mock( 'create', sub { shift; push @created_statistics, shift; return 1; } );

    # Mock print job result set
    my $print_job_rs = Test::MockObject->new();
    $print_job_rs->mock( 'find', sub {
        return $opts{print_job};
    });

    # Mock user object for $c->user
    my $c_user = $opts{c_user} // $opts{user} // build_mock_user();

    my $c = Test::MockObject->new();
    $c->mock( 'instance',  sub { return 'TEST'; } );
    $c->mock( 'log',       sub { return $log; } );
    $c->mock( 'now',       sub { return '2026-02-13 12:00:00'; } );
    $c->mock( 'sessionid', sub { return 'test-session-id'; } );
    $c->mock( 'user',      sub { return $c_user; } );
    $c->mock( 'model', sub {
        my ( $self, $model_name ) = @_;
        return $print_job_rs   if $model_name eq 'DB::PrintJob';
        return $stat_rs        if $model_name eq 'DB::Statistic';
        return undef;
    });

    return ( $c, \@created_statistics );
}

# Helper to build a mock user object
sub build_mock_user {
    my (%opts) = @_;
    my $user = Test::MockObject->new();
    $user->mock( 'id',       sub { return $opts{id} // 1; } );
    $user->mock( 'username', sub { return $opts{username} // 'testuser'; } );
    return $user;
}

# Helper to build a mock print job
sub build_mock_print_job {
    my (%opts) = @_;
    my $_status = 'Held';
    my $pj = Test::MockObject->new();
    $pj->mock( 'id',      sub { return $opts{id} // 1; } );
    $pj->mock( 'user_id', sub { return $opts{user_id} // 1; } );
    $pj->mock( 'status', sub {
        my ( $self, $val ) = @_;
        $_status = $val if @_ > 1;
        return $_status;
    });
    $pj->mock( 'update', sub { return 1; } );
    return ( $pj, \$_status );
}

# Tests
subtest 'Cancel succeeds and logs statistic' => sub {
    my $user = build_mock_user( id => 1 );
    my ( $print_job, $status ) = build_mock_print_job( user_id => 1 );
    my ( $c, $stats ) = build_mock_c( user => $user, print_job => $print_job );

    my $result = Libki::Utils::Printing::cancel( $c, 1, $user );

    is( $result->{success}, 1, 'Cancel succeeded' );
    is( $$status, 'Canceled', 'Status updated to Canceled' );
    is( scalar @$stats, 1, 'One statistic created' );
    is( $stats->[0]->{action}, 'PRINT_JOB_CANCELED', 'Statistic is PRINT_JOB_CANCELED' );
    is( $stats->[0]->{username}, 'testuser', 'Correct username in statistic' );
};

subtest 'Cancel fails if user does not match' => sub {
    my $user = build_mock_user( id => 2 );
    my ( $print_job, $status ) = build_mock_print_job( user_id => 1 );
    my ( $c, $stats ) = build_mock_c( user => $user, print_job => $print_job );

    my $result = Libki::Utils::Printing::cancel( $c, 1, $user );

    is( $result->{success}, 0, 'Cancel failed' );
    is( $result->{error}, 'User does not match', 'Error message is correct' );
    is( scalar @$stats, 0, 'No statistic created' );
};

subtest 'Cancel succeeds without user Param (admin-like behavior)' => sub {
    my $admin = build_mock_user( username => 'admin' );
    my ( $print_job, $status ) = build_mock_print_job( user_id => 1 );
    my ( $c, $stats ) = build_mock_c( user => $admin, print_job => $print_job );

    my $result = Libki::Utils::Printing::cancel( $c, 1, undef );

    is( $result->{success}, 1, 'Cancel succeeded' );
    is( scalar @$stats, 1, 'Statistic created' );
    is( $stats->[0]->{action}, 'PRINT_JOB_CANCELED', 'Action is correct' );
};

done_testing();
