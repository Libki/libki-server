use Modern::Perl;
use Test::More;
use Test::MockObject;

use JSON qw(to_json);

use Libki::Utils::Printing;

# Helper to build a mock $c context object
sub build_mock_c {
    my (%opts) = @_;

    my $gratis_method = $opts{gratis_method} // '';

    # Mock log object
    my $log = Test::MockObject->new();
    $log->mock( 'info',  sub { } );
    $log->mock( 'debug', sub { } );
    $log->mock( 'error', sub { } );

    # Track statistics created
    my @created_statistics;
    my $stat_rs = Test::MockObject->new();
    $stat_rs->mock( 'create', sub { shift; push @created_statistics, shift; return 1; } );
    $stat_rs->mock('search', sub {
        my $rs = Test::MockObject->new();
        $rs->mock('all', sub { return map { my $h=$_; my $o=Test::MockObject->new(); $o->mock('info',sub{$h->{info}}); $o; } @created_statistics; });
        return $rs;
    });

    # Mock DB model (for txn_do — just runs the sub immediately)
    my $db_model = Test::MockObject->new();
    $db_model->mock( 'txn_do', sub { my ( $self, $code ) = @_; $code->(); } );

    # Mock print job result set
    my @created_print_jobs;
    my $print_job_rs = Test::MockObject->new();
    $print_job_rs->mock( 'find', sub {
        my ($self,$where)=@_;
        return $opts{created_print_job} if $opts{created_print_job} && $where->{id} == $opts{created_print_job}->id;
        return $opts{print_job};
    });

    $print_job_rs->mock( 'search', sub {
        my ( $self, $where ) = @_;
        my $claim_rs = Test::MockObject->new();
        $claim_rs->mock('single',sub{$opts{print_job}});
        $claim_rs->mock( 'update', sub {
            my ( $claim_self, $changes ) = @_;
            return 0 if $opts{claim_fails};

            my $job = $opts{print_job};
            return 0 unless $job;
            return 0 if exists $where->{id} && $where->{id} != $job->id;
            return 0 if exists $where->{status} && $where->{status} ne $job->status;

            $job->copies( $changes->{copies} ) if exists $changes->{copies};
            $job->status( $changes->{status} ) if exists $changes->{status};
            return 1;
        });
        return $claim_rs;
    });
    $print_job_rs->mock( 'create', sub {
        my ( $self, $values ) = @_;
        push @created_print_jobs, $values;
        return $opts{created_print_job};
    });

    # Mock print file result set
    my $print_file_rs = Test::MockObject->new();
    $print_file_rs->mock( 'find', sub {
        return $opts{print_file};
    });

    # Printer configuration
    my $printer_config = $opts{printer_config} // {
        printers => {}
    };

    # Mock user object for $c->user (used inside calculate_job_cost and txn_do block)
    my $c_user = $opts{c_user} // $opts{user};

    my $c = Test::MockObject->new();
    $c->mock( 'instance',  sub { return 'TEST'; } );
    $c->mock( 'log',       sub { return $log; } );
    $c->mock( 'now',       sub { return '2026-02-13 12:00:00'; } );
    $c->mock( 'sessionid', sub { return 'test-session-id'; } );
    $c->mock( 'user',      sub { return $c_user; } );
    $c->mock( 'get_printer_configuration', sub { return $printer_config; } );
    $c->mock( 'setting', sub {
        my ( $self, $name ) = @_;
        if ( $name eq 'GratisPrintingMethod' ) {
            return $gratis_method;
        }
        return '';
    });
    $c->mock( 'check_user_roles', sub {
        my ( $self, $role ) = @_;
        return $opts{is_admin} // 0;
    });
    $c->mock( 'model', sub {
        my ( $self, $model_name ) = @_;
        return $print_job_rs   if $model_name eq 'DB::PrintJob';
        return $print_file_rs  if $model_name eq 'DB::PrintFile';
        return $stat_rs        if $model_name eq 'DB::Statistic';
        return $db_model       if $model_name eq 'DB';
        return undef;
    });

    return ( $c, \@created_statistics, \@created_print_jobs );
}

# Helper to build a mock user object
sub build_mock_user {
    my (%opts) = @_;

    my $_funds                = $opts{funds}                // 10.00;
    my $_gratis_print_balance = $opts{gratis_print_balance} // 0;
    my $_id                   = $opts{id}                   // 1;
    my $_username             = $opts{username}              // 'testuser';
    my $_firstname            = $opts{firstname}             // 'Test';
    my $_lastname             = $opts{lastname}              // 'Patron';
    my $_debit_called         = 0;
    my $_debit_amount         = 0;

    my $_credit_called        = 0;
    my $_credit_amount        = 0;
    my $user = Test::MockObject->new();
    $user->mock( 'id',       sub { return $_id; } );
    $user->mock( 'username', sub { return $_username; } );
    $user->mock( 'firstname', sub { return $_firstname; } );
    $user->mock( 'lastname',  sub { return $_lastname; } );
    $user->mock( 'funds',    sub { return $_funds; } );
    $user->mock( 'gratis_print_balance', sub {
        my ( $self, $val ) = @_;
        if ( @_ > 1 && defined $val ) {
            $_gratis_print_balance = $val;
            return $self;
        }
        return $_gratis_print_balance;
    });
    $user->mock( 'debit_funds', sub {
        my ( $self, $c, $amount ) = @_;
        $_debit_called++;
        $_debit_amount = $amount;
        $_funds -= $amount;
        return 1;
    });
    $user->mock( 'credit_funds', sub {
        my ( $self, $c, $amount ) = @_;
        $_credit_called++;
        $_credit_amount = $amount;
        $_funds += $amount;
        return 1;
    });
    $user->mock( 'discard_changes', sub { return; } );
    $user->mock( 'update', sub { return 1; } );

    return ( $user, \$_debit_called, \$_debit_amount, \$_gratis_print_balance,
        \$_credit_called, \$_credit_amount, \$_funds );
}

# Helper to build a mock print job
sub build_mock_print_job {
    my (%opts) = @_;

    my $_copies = $opts{copies} // 1;
    my $_printer = $opts{printer}  // 'printer1';
    my $_status  = $opts{status}   // 'Held';
    my $_type    = $opts{type}     // 'PrintManager';
    my $_update_called = 0;
    my %_last_update;

    my $pj = Test::MockObject->new();
    $pj->mock( 'id',            sub { return $opts{id} // 1; } );
    $pj->mock( 'data',          sub { return undef; } );
    $pj->mock( 'user_id',       sub { return $opts{user_id} // 1; } );
    $pj->mock( 'print_file_id', sub { return $opts{print_file_id} // 100; } );
    $pj->mock( 'copies', sub { my ($self,$v)=@_; $_copies=$v if defined $v; return $_copies; } );
    $pj->mock( 'type',          sub { return $_type; } );
    $pj->mock( 'printer', sub {
        my ( $self, $val ) = @_;
        if ( @_ > 1 && defined $val ) {
            $_printer = $val;
            return $self;
        }
        return $_printer;
    });
    $pj->mock( 'status', sub {
        my ( $self, $val ) = @_;
        if ( @_ > 1 && defined $val ) {
            $_status = $val;
            return $self;
        }
        return $_status;
    });
    $pj->mock( 'update', sub {
        my ( $self, $args ) = @_;
        $_update_called = 1;
        if ( ref $args eq 'HASH' ) {
            %_last_update = %{$args};
            $_status = $args->{status} if exists $args->{status};
        }
        return 1;
    });
    $pj->mock( 'discard_changes', sub { return; } );
    $pj->mock( 'print_file', sub { return $opts{print_file}; } );
    $pj->mock( 'user',       sub { return $opts{user_obj}; } );

    return ( $pj, \$_status, \$_update_called, \%_last_update );
}

# Helper to build a mock print file
sub build_mock_print_file {
    my (%opts) = @_;
    my $pf = Test::MockObject->new();
    $pf->mock( 'id',       sub { return $opts{id}       // 100; } );
    $pf->mock( 'pages',    sub { return $opts{pages}    // 5; } );
    $pf->mock( 'filename', sub { return $opts{filename} // 'test.pdf'; } );
    $pf->mock( 'client_name', sub { return $opts{client_name} // 'SAMPLE-PC-01'; } );
    $pf->mock( 'client_location', sub { return $opts{client_location} // 'CPL Main'; } );
    $pf->mock( 'data',     sub { return 'fake-pdf-data'; } );
    return $pf;
}


# ========================================================================
# Tests
# ========================================================================

subtest 'User does not match print job' => sub {
    my ( $user ) = build_mock_user( id => 99 );  # user id 99

    my $print_file = build_mock_print_file();
    my ( $print_job ) = build_mock_print_job(
        user_id    => 1,  # job belongs to user 1
        print_file => $print_file,
    );

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 0, 'Should fail' );
    is( $result->{error}, 'User does not match', 'Error message is correct' );
};

subtest 'Print job not found is handled before printer lookup' => sub {
    my ( $user ) = build_mock_user();

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => undef,
        print_file => undef,
        printer_config => { printers => {} },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 404,
        user         => $user,
    });

    is( $result->{success}, 0, 'Missing job fails safely' );
    is( $result->{error}, 'Print Job Not Found', 'Error message is correct' );
    is( $result->{id}, 404, 'Missing job id is returned' );
};

subtest 'Non-admin without user param is rejected' => sub {
    my ( $user ) = build_mock_user();
    my $print_file = build_mock_print_file();
    my ( $print_job ) = build_mock_print_job(
        user_obj   => $user,
        print_file => $print_file,
    );

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        is_admin   => 0,
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => undef,  # no user passed
    });

    is( $result->{success}, 0, 'Should fail' );
    like( $result->{error}, qr/does not have rights/, 'Error message about rights' );
};

subtest 'Non-held print job is rejected before charging' => sub {
    my ( $user, $debit_called ) = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file();
    my ( $print_job ) = build_mock_print_job(
        status     => 'Pending',
        user_obj   => $user,
        print_file => $print_file,
    );

    my ( $c, $stats ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 0, 'Non-held job fails' );
    is( $result->{error}, 'Print Job Is Not Held', 'Failure is explicit' );
    is( $$debit_called, 0, 'Patron was not charged' );
    is( scalar @$stats, 0, 'No release statistic was recorded' );
};

subtest 'Lost atomic claim is rejected before charging' => sub {
    my ( $user, $debit_called ) = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file();
    my ( $print_job ) = build_mock_print_job( user_obj => $user, print_file => $print_file );

    my ( $c, $stats ) = build_mock_c(
        user        => $user,
        print_job   => $print_job,
        print_file  => $print_file,
        claim_fails => 1,
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 0, 'Losing request fails' );
    is( $result->{error}, 'Print Job Is Not Held', 'Race is reported as already claimed' );
    is( $$debit_called, 0, 'Losing request did not charge the patron' );
    is( scalar @$stats, 0, 'Losing request did not record a release' );
};

subtest 'Repeated release debits and records exactly once' => sub {
    my ( $user, $debit_called, $debit_amount ) = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $pj_status ) = build_mock_print_job( user_obj => $user, print_file => $print_file );

    my ( $c, $stats ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $first = Libki::Utils::Printing::release( $c, { print_job_id => 1, user => $user } );
    my $second = Libki::Utils::Printing::release( $c, { print_job_id => 1, user => $user } );

    is( $first->{success}, 1, 'First release succeeds' );
    is( $second->{success}, 0, 'Repeated release fails' );
    is( $second->{error}, 'Print Job Is Not Held', 'Repeated release is rejected by status' );
    is( $$debit_called, 1, 'Patron was debited exactly once' );
    is( $$debit_amount, 0.50, 'Only the intended charge was applied' );
    is( $$pj_status, 'Pending', 'Job remains Pending after the rejected retry' );
    is( scalar( grep { $_->{action} eq 'PRINT_JOB_RELEASED' } @$stats ), 1,
        'Exactly one release statistic was recorded' );
};

subtest 'Print file not found' => sub {
    my ( $user ) = build_mock_user();
    my ( $print_job ) = build_mock_print_job();

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => undef,  # print file not found in DB
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 0, 'Should fail' );
    is( $result->{error}, 'Print File Not Found', 'Error message is correct' );
};

subtest 'Printer not found in configuration' => sub {
    my ( $user ) = build_mock_user();
    my $print_file = build_mock_print_file();
    my ( $print_job ) = build_mock_print_job(
        printer    => 'nonexistent',
        print_file => $print_file,
    );

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => { printers => {} },  # no printers configured
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 0, 'Should fail' );
    is( $result->{error}, 'Printer Not Found', 'Error message is correct' );
};

subtest 'Insufficient funds' => sub {
    my ( $user ) = build_mock_user( funds => 0.01 );  # very low funds
    my $print_file = build_mock_print_file( pages => 10 );
    my ( $print_job ) = build_mock_print_job(
        copies     => 2,  # 20 pages total
        print_file => $print_file,
    );

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => { printers => { printer1 => { cost_per_page => 1.00, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 0, 'Should fail' );
    is( $result->{error}, 'Insufficient funds', 'Error message is correct' );
};

subtest 'Successful release with no gratis discount (PrintManager)' => sub {
    my ( $user, $debit_called, $debit_amount ) = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $pj_status ) = build_mock_print_job(
        copies     => 1,
        print_file => $print_file,
        user_obj   => $user,
    );

    my ( $c, $stats ) = build_mock_c(
        user          => $user,
        print_job     => $print_job,
        print_file    => $print_file,
        gratis_method => '',
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 1, 'Should succeed' );
    is( $$debit_called, 1, 'debit_funds was called' );
    is( $$debit_amount, 0.50, 'Debited correct amount (5 pages * $0.10)' );
    is( $$pj_status, 'Pending', 'Print job status set to Pending' );
    is( scalar @$stats, 1, 'One statistic created' );
    is( $stats->[0]->{action}, 'PRINT_JOB_RELEASED', 'Statistic is PRINT_JOB_RELEASED' );
};

subtest 'Successful release with gratis discount - pages method (partial)' => sub {
    my ( $user, $debit_called, $debit_amount, $gratis_bal )
        = build_mock_user( funds => 10.00, gratis_print_balance => 3 );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $pj_status ) = build_mock_print_job(
        copies     => 1,
        print_file => $print_file,
        user_obj   => $user,
    );

    my ( $c, $stats ) = build_mock_c(
        user          => $user,
        print_job     => $print_job,
        print_file    => $print_file,
        gratis_method => 'pages',
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 1, 'Should succeed' );
    # 5 pages - 3 gratis = 2 pages billable => 2 * 0.10 = 0.20
    is( $$debit_amount, 0.20, 'Debited correct amount after gratis pages discount' );
    is( scalar @$stats, 2, 'Two statistics created' );
    is( $stats->[0]->{action}, 'GRATIS_DISCOUNT', 'First statistic is GRATIS_DISCOUNT' );
    is( $stats->[1]->{action}, 'PRINT_JOB_RELEASED', 'Second statistic is PRINT_JOB_RELEASED' );
};

subtest 'Successful release with gratis discount - balance method' => sub {
    my ( $user, $debit_called, $debit_amount, $gratis_bal )
        = build_mock_user( funds => 10.00, gratis_print_balance => 0.30 );  # 30 cents gratis
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $pj_status ) = build_mock_print_job(
        copies     => 1,
        print_file => $print_file,
        user_obj   => $user,
    );

    my ( $c, $stats ) = build_mock_c(
        user          => $user,
        print_job     => $print_job,
        print_file    => $print_file,
        gratis_method => 'funds',
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 1, 'Should succeed' );
    # 5 pages * 0.10 = 0.50 cost, gratis balance 30, so cost = 0.20, discount = 0.30
    is( $$debit_amount, 0.20, 'Debited correct amount after partial gratis balance discount' );
    is( scalar @$stats, 2, 'Two statistics created' );
    is( $stats->[0]->{action}, 'GRATIS_DISCOUNT', 'First statistic is GRATIS_DISCOUNT' );
    is( $stats->[1]->{action}, 'PRINT_JOB_RELEASED', 'Second statistic is PRINT_JOB_RELEASED' );
};

subtest 'Successful release with gratis discount - pages method covers all pages' => sub {
    my ( $user, $debit_called, $debit_amount, $gratis_bal )
        = build_mock_user( funds => 10.00, gratis_print_balance => 10 );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $pj_status ) = build_mock_print_job(
        copies     => 1,
        print_file => $print_file,
        user_obj   => $user,
    );

    my ( $c, $stats ) = build_mock_c(
        user          => $user,
        print_job     => $print_job,
        print_file    => $print_file,
        gratis_method => 'pages',
        printer_config => { printers => { printer1 => { cost_per_page => 0.10, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 1, 'Should succeed' );
    # 5 pages, 10 gratis pages > 5 total, so all pages free, discount = 5
    is( $$debit_amount, 0, 'Debited zero when gratis pages cover everything' );
    is( scalar @$stats, 2, 'Two statistics created' );
    is( $stats->[0]->{action}, 'GRATIS_DISCOUNT', 'First statistic is GRATIS_DISCOUNT' );
    is( $stats->[1]->{action}, 'PRINT_JOB_RELEASED', 'Second statistic is PRINT_JOB_RELEASED' );
};

subtest 'Printer changed at release time' => sub {
    my ( $user, $debit_called, $debit_amount ) = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file( pages => 1 );
    my ( $print_job, $pj_status, $pj_update_called ) = build_mock_print_job(
        print_file => $print_file,
        user_obj   => $user,
    );

    my ( $c, $stats ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => {
            printers => {
                printer1 => { cost_per_page => 0.10, type => 'PrintManager' },
                printer2 => { cost_per_page => 0.25, type => 'PrintManager' },
            }
        },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
        printer      => 'printer2',
    });

    is( $result->{success}, 1, 'Should succeed' );
    # Cost should use new printer: 1 page * $0.25 = $0.25
    is( $$debit_amount, 0.25, 'Cost calculated using the new printer' );
};

subtest 'Zero cost job succeeds without debit issues' => sub {
    my ( $user, $debit_called, $debit_amount ) = build_mock_user( funds => 0 );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job ) = build_mock_print_job(
        print_file => $print_file,
        user_obj   => $user,
    );

    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => { printers => { printer1 => { cost_per_page => 0, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => $user,
    });

    is( $result->{success}, 1, 'Should succeed with zero cost' );
    is( $$debit_amount, 0, 'Zero amount debited' );
};

subtest 'Admin can release without user param' => sub {
    my ( $user ) = build_mock_user();
    my $print_file = build_mock_print_file( pages => 1 );
    my ( $print_job ) = build_mock_print_job(
        user_obj   => $user,
        print_file => $print_file,
    );

    my ( $c, $stats ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        is_admin   => 1,
        printer_config => { printers => { printer1 => { cost_per_page => 0, type => 'PrintManager' } } },
    );

    my $result = Libki::Utils::Printing::release( $c, {
        print_job_id => 1,
        user         => undef,  # admin, no user passed
    });

    is( $result->{success}, 1, 'Admin release should succeed' );
    is( scalar @$stats, 1, 'One statistic created' );
    is( $stats->[0]->{action}, 'PRINT_JOB_RELEASED', 'Statistic is PRINT_JOB_RELEASED' );
};
subtest 'Known CUPS failure restores Held and refunds exactly once' => sub {
    my ( $user, $debit_called, $debit_amount, $gratis_balance,
        $credit_called, $credit_amount, $funds )
        = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $pj_status ) = build_mock_print_job(
        type       => 'cups',
        user_obj   => $user,
        print_file => $print_file,
    );

    my ( $c, $stats ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => {
            staff_print_release => 'enabled',
            printers => { printer1 => { cost_per_page => 0.10, name => 'missing-cups-queue' } },
        },
    );

    my $cups = Test::MockObject->new();
    $cups->mock( 'getDestination', sub { return undef; } );

    my $result;
    {
        no warnings 'redefine';
        local *Libki::Utils::Printing::cups_setup = sub { return $cups; };
        $result = Libki::Utils::Printing::release( $c, {
            print_job_id => 1,
            user         => $user,
        });
    }

    is( $result->{success}, 0, 'Release fails when CUPS has no destination' );
    is( $result->{safe_to_retry}, 1, 'Failure is known not to have submitted' );
    is( $$debit_called, 1, 'Initial charge was recorded once' );
    is( $$credit_called, 1, 'Automatic refund was recorded once' );
    is( $$credit_amount, $$debit_amount, 'Refund exactly matches the charge' );
    is( $$funds, 10.00, 'Net patron funds are unchanged' );
    is( $$pj_status, 'Held', 'Job is restored to Held for a later staff retry' );
    is( scalar( grep { $_->{action} eq 'PRINT_JOB_RELEASE_FAILED' } @$stats ), 1,
        'Failed release is audited once' );
    is( scalar( grep { $_->{action} eq 'PRINT_JOB_RELEASED' } @$stats ), 0,
        'Failed release is not recorded as released' );
};

subtest 'Uncertain CUPS submission is not refunded or made retryable' => sub {
    my ( $user, $debit_called, $debit_amount, $gratis_balance,
        $credit_called, $credit_amount, $funds )
        = build_mock_user( funds => 10.00 );
    my $print_file = build_mock_print_file( pages => 5, filename => 'patron-document.pdf' );
    my ( $print_job, $pj_status ) = build_mock_print_job(
        type       => 'cups',
        user_obj   => $user,
        print_file => $print_file,
    );

    my ( $c, $stats ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => {
            staff_print_release => 'enabled',
            printers => { printer1 => { cost_per_page => 0.10, name => 'cpl-main-bw' } },
        },
    );

    my $job_title;
    my $destination = Test::MockObject->new();
    $destination->mock( 'addOption', sub { return 1; } );
    $destination->mock( 'printFile', sub {
        my ( $self, $filename, $title ) = @_;
        $job_title = $title;
        die 'simulated connection loss during submission';
    });
    my $cups = Test::MockObject->new();
    $cups->mock( 'getDestination', sub { return $destination; } );

    my $result;
    {
        no warnings 'redefine';
        local *Libki::Utils::Printing::cups_setup = sub { return $cups; };
        $result = Libki::Utils::Printing::release( $c, {
            print_job_id => 1,
            user         => $user,
        });
    }

    is( $result->{success}, 0, 'Uncertain submission stops the release' );
    is( $result->{safe_to_retry}, 0, 'Uncertain submission is explicitly non-retryable' );
    is( $result->{manual_review}, 1, 'Staff review is required' );
    is( $$debit_called, 1, 'Charge remains singular' );
    is( $$credit_called, 0, 'No unsafe automatic refund is created' );
    isnt( $$pj_status, 'Held', 'Job cannot be released a second time' );
    like( $job_title, qr{^libki-TEST-1-}, 'CUPS title carries the Libki job id' );
    is( scalar( grep { $_->{action} eq 'PRINT_JOB_RELEASED' } @$stats ), 0,
        'Uncertain release is not falsely recorded as successful' );
};

subtest 'Accepted CUPS job becomes terminal Done with queue audit fields' => sub {
    my ( $user ) = build_mock_user();
    my $print_file = build_mock_print_file( filename => 'accepted.pdf' );
    my ( $print_job, $status, $update_called, $last_update )
        = build_mock_print_job(
            type       => 'cups',
            status     => 'Pending',
            user_obj   => $user,
            print_file => $print_file,
        );
    my ( $c ) = build_mock_c(
        user       => $user,
        print_job  => $print_job,
        print_file => $print_file,
    );

    my $destination = Test::MockObject->new();
    $destination->mock( 'addOption', sub { return 1; } );
    $destination->mock( 'printFile', sub { return 42; } );
    $destination->mock( 'getJob', sub {
        return { id => 42, state_text => 'processing' };
    });
    my $cups = Test::MockObject->new();
    $cups->mock( 'getDestination', sub { return $destination; } );

    my $result;
    {
        no warnings 'redefine';
        local *Libki::Utils::Printing::cups_setup = sub { return $cups; };
        $result = Libki::Utils::Printing::release_for_cups(
            $c,
            {
                print_job  => $print_job,
                print_file => $print_file,
                printer    => {
                    name     => 'cpl-main-bw',
                    chroming => 'monochrome',
                    plexing  => 'simplex',
                },
            }
        );
    }

    is( $result->{success}, 1, 'Accepted CUPS submission succeeds' );
    is( $$status, 'Done', 'Transient CUPS processing state becomes terminal Done' );
    is( $last_update->{queued_to}, 'cpl-main-bw', 'Physical queue is recorded' );
    is( $last_update->{queued_on}, '2026-02-13 12:00:00', 'Queue time is recorded' );
};

subtest 'CUPS options enforce queue color mode, simplex, and copies' => sub {
    my ( $user ) = build_mock_user();
    my ( $print_job ) = build_mock_print_job(
        copies   => 3,
        user_obj => $user,
    );

    my $options = Libki::Utils::Printing::cups_job_options(
        $print_job,
        {
            chroming => 'monochrome',
            plexing  => 'simplex',
        }
    );

    is_deeply(
        $options,
        {
            copies             => 3,
            'print-color-mode' => 'monochrome',
            sides              => 'one-sided',
        },
        'B&W queue policy cannot be overridden by client print-dialog choices'
    );
};

subtest 'Staff release preview is side-effect free and authoritative' => sub {
    my ( $patron, $debit_called ) = build_mock_user(
        username  => '23691001000000',
        firstname => 'Alex',
        lastname  => 'Reader',
    );
    my $print_file = build_mock_print_file(
        pages           => 5,
        filename        => 'research.pdf',
        client_name     => 'SAMPLE-PC-01',
        client_location => 'CPL Main',
    );
    my ( $print_job, $status, $update_called ) = build_mock_print_job(
        copies     => 2,
        user_obj   => $patron,
        print_file => $print_file,
    );
    my ( $c, $stats ) = build_mock_c(
        user       => $patron,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => {
            staff_print_release => 'disabled',
            printers => {
                printer1 => {
                    cost_per_page => 0.35,
                    public_printer_name => 'Main Floor - Color',
                    release_location => 'the Main Floor service desk',
                    allowed_client_locations => ['CPL Main'],
                },
            },
        },
    );

    my $preview = Libki::Utils::Printing::build_release_preview(
        $c, { print_job_id => 1 }
    );

    is( $preview->{success}, 1, 'Preview succeeds' );
    is( $preview->{patron_name}, 'Alex Reader', 'Preview shows patron name' );
    is( $preview->{library_card}, '23691001000000', 'Preview shows library card' );
    is( $preview->{client_location}, 'CPL Main', 'Preview shows client location' );
    is( $preview->{printer_name}, 'Main Floor - Color', 'Preview shows public printer name' );
    is( $preview->{release_location}, 'the Main Floor service desk', 'Preview shows release desk' );
    is( $preview->{total_pages}, 10, 'Preview multiplies pages by copies' );
    is( $preview->{amount_due}, '3.50', 'Preview calculates authoritative amount' );
    is( $preview->{release_allowed}, 0, 'Disabled mode cannot release' );
    is( $$debit_called, 0, 'Preview performs no debit' );
    is( $$update_called, 0, 'Preview does not update the job' );
    is( scalar @$stats, 0, 'Preview creates no statistics' );
};

subtest 'Preview and release location helper reject a cross-site queue' => sub {
    my ( $patron ) = build_mock_user();
    my $print_file = build_mock_print_file( client_location => 'CPL Main' );
    my ( $print_job ) = build_mock_print_job(
        user_obj   => $patron,
        print_file => $print_file,
    );
    my ( $c ) = build_mock_c(
        user       => $patron,
        print_job  => $print_job,
        print_file => $print_file,
        printer_config => {
            printers => {
                printer1 => {
                    cost_per_page => 0.15,
                    allowed_client_locations => ['CPL Genealogy'],
                },
            },
        },
    );

    my $preview = Libki::Utils::Printing::build_release_preview(
        $c, { print_job_id => 1 }
    );
    is( $preview->{success}, 0, 'Cross-site preview fails' );
    is( $preview->{error}, 'PRINTER_NOT_AVAILABLE_AT_CLIENT_LOCATION',
        'Cross-site error is explicit' );
};

subtest 'Completed CUPS job can create an audited production reprint' => sub {
    my ( $patron ) = build_mock_user(
        id       => 7,
        username => '23691001077246',
    );
    my ( $staff ) = build_mock_user(
        id       => 99,
        username => 'library.staff',
    );
    my $print_file = build_mock_print_file(
        id              => 400,
        pages           => 2,
        client_name     => 'SAMPLE-PC-01',
        client_location => 'CPL Main',
    );
    my ( $source_job ) = build_mock_print_job(
        id            => 41,
        status        => 'Done',
        type          => 'cups',
        copies        => 2,
        user_id       => 7,
        print_file_id => 400,
        user_obj      => $patron,
        print_file    => $print_file,
    );
    my ( $new_job, $new_status ) = build_mock_print_job(
        id            => 42,
        status        => 'Held',
        type          => 'cups',
        copies        => 2,
        user_id       => 7,
        print_file_id => 400,
        user_obj      => $patron,
        print_file    => $print_file,
    );
    my ( $c, $stats, $created_jobs ) = build_mock_c(
        user              => $patron,
        c_user            => $staff,
        print_job         => $source_job,
        created_print_job => $new_job,
        print_file        => $print_file,
        is_admin          => 1,
        printer_config    => {
            staff_print_release => 'enabled',
            printers => {
                printer1 => {
                    cost_per_page => 0.15,
                    allowed_client_locations => ['CPL Main'],
                },
            },
        },
    );

    my $preview = Libki::Utils::Printing::build_release_preview(
        $c, { print_job_id => 41 }
    );
    is( $preview->{release_allowed}, 0, 'Completed source cannot be released again' );
    is( $preview->{reprint_allowed}, 1, 'Completed CUPS source can be reprinted' );
    is( $preview->{action_mode}, 'reprint', 'Preview selects reprint mode' );
    is( $preview->{amount_due}, '0.60', 'Reprint uses authoritative current price' );

    my $result = Libki::Utils::Printing::create_reprint_job(
        $c,
        {
            print_job_id    => 41,
            expected_amount => '0.60',
        }
    );

    is( $result->{success}, 1, 'Reprint job creation succeeds' );
    is( $result->{source_print_job_id}, 41, 'Original job remains the source' );
    is( $result->{reprint_job_id}, 42, 'New job id is returned' );
    is( scalar @$created_jobs, 1, 'Exactly one new print job is created' );
    is( $created_jobs->[0]->{status}, 'Held', 'New job enters normal Held workflow' );
    is( $created_jobs->[0]->{print_file_id}, 400, 'New job safely reuses retained PDF' );
    is( $created_jobs->[0]->{printer}, 'printer1', 'New job preserves authoritative queue' );
    is( scalar( grep { $_->{action} eq 'PRINT_JOB_REPRINT_CREATED' } @$stats ), 1,
        'Reprint creation is audited once' );
    is( $source_job->status, 'Done', 'Original completed history is unchanged' );
    is( $$new_status, 'Held', 'New job remains held until normal release claims it' );
};

subtest 'Confirmed staff cash release records cash without debiting patron funds' => sub {
    my ( $patron, $debit_called, $debit_amount, $gratis_balance,
        $credit_called, $credit_amount, $funds )
        = build_mock_user( funds => 0, username => '23691001000001' );
    my ( $staff ) = build_mock_user( id => 99, username => 'library.staff' );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $status ) = build_mock_print_job(
        type       => 'PrintManager',
        user_obj   => $patron,
        print_file => $print_file,
    );
    my ( $c, $stats ) = build_mock_c(
        user       => $patron,
        c_user     => $staff,
        print_job  => $print_job,
        print_file => $print_file,
        is_admin   => 1,
        printer_config => {
            staff_print_release => 'enabled',
            printers => { printer1 => { cost_per_page => 0.10 } },
        },
    );

    my $result = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id    => 1,
            payment_method  => 'cash',
            expected_amount => '0.50',
        }
    );

    is( $result->{success}, 1, 'Cash release succeeds' );
    is( $$debit_called, 0, 'Cash release does not debit patron funds' );
    is( $$funds, 0, 'Patron funds remain unchanged' );
    is( $$status, 'Pending', 'Released job moves to Pending' );
    is( scalar( grep { $_->{action} eq 'PRINT_PAYMENT_CASH' } @$stats ), 1,
        'Cash receipt is audited once' );
    is( scalar( grep { $_->{action} eq 'PRINT_JOB_RELEASED' } @$stats ), 1,
        'Release is audited once' );
};

subtest 'Stale reviewed cash amount is rejected before claiming the job' => sub {
    my ( $patron, $debit_called ) = build_mock_user( funds => 0 );
    my ( $staff ) = build_mock_user( id => 99, username => 'library.staff' );
    my $print_file = build_mock_print_file( pages => 5 );
    my ( $print_job, $status, $update_called ) = build_mock_print_job(
        type       => 'PrintManager',
        user_obj   => $patron,
        print_file => $print_file,
    );
    my ( $c, $stats ) = build_mock_c(
        user       => $patron,
        c_user     => $staff,
        print_job  => $print_job,
        print_file => $print_file,
        is_admin   => 1,
        printer_config => {
            staff_print_release => 'enabled',
            printers => { printer1 => { cost_per_page => 0.10 } },
        },
    );

    my $result = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id    => 1,
            payment_method  => 'cash',
            expected_amount => '0.40',
        }
    );

    is( $result->{success}, 0, 'Stale amount fails' );
    is( $result->{error}, 'PRINT_COST_CHANGED', 'Stale amount error is explicit' );
    is( $result->{amount_due}, '0.50', 'Current amount is returned' );
    is( $$status, 'Held', 'Job remains Held' );
    is( $$debit_called, 0, 'No debit occurs' );
    is( $$update_called, 0, 'Job is not claimed' );
    is( scalar @$stats, 0, 'No cash or release audit is written' );
};

subtest 'Disabled staff CUPS release is blocked before accounting or submission' => sub {
    my ( $patron, $debit_called ) = build_mock_user( funds => 0 );
    my ( $staff ) = build_mock_user( id => 99, username => 'library.staff' );
    my $print_file = build_mock_print_file( pages => 1 );
    my ( $print_job, $status, $update_called ) = build_mock_print_job(
        type       => 'cups',
        user_obj   => $patron,
        print_file => $print_file,
    );
    my ( $c, $stats ) = build_mock_c(
        user       => $patron,
        c_user     => $staff,
        print_job  => $print_job,
        print_file => $print_file,
        is_admin   => 1,
        printer_config => {
            staff_print_release => 'disabled',
            printers => { printer1 => { cost_per_page => 0.15 } },
        },
    );

    my $result = Libki::Utils::Printing::release(
        $c,
        {
            print_job_id    => 1,
            payment_method  => 'cash',
            expected_amount => '0.15',
        }
    );

    is( $result->{success}, 0, 'Disabled CUPS release fails' );
    is( $result->{error}, 'STAFF_PRINT_RELEASE_DISABLED', 'Safety gate is explicit' );
    is( $$status, 'Held', 'Job remains Held' );
    is( $$debit_called, 0, 'No debit occurs' );
    is( $$update_called, 0, 'Job is not claimed' );
    is( scalar @$stats, 0, 'No accounting or release audit is written' );
};



subtest 'Staff quantities are authoritative and duplicate release is safe' => sub {
    for my $price (0.15,0.35) {
        my ($patron)=build_mock_user(funds=>0);
        my ($staff)=build_mock_user(id=>99,username=>'test.staff');
        my $file=build_mock_print_file(pages=>4);
        my ($job,$status)=build_mock_print_job(type=>'PrintManager',user_obj=>$patron,print_file=>$file);
        $job->mock('data',sub{return undef;});
        my ($c,$stats)=build_mock_c(user=>$patron,c_user=>$staff,print_job=>$job,print_file=>$file,is_admin=>1,
            printer_config=>{staff_print_release=>'enabled',printers=>{printer1=>{cost_per_page=>$price}}});
        my $preview=Libki::Utils::Printing::build_release_preview($c,{print_job_id=>1,copies=>3});
        is($preview->{total_pages},12,'copies multiply the document page count');
        is($preview->{amount_due},sprintf('%.2f',12*$price),'authoritative pricing');
        is($job->copies,1,'preview does not mutate the stored copy count');
        for my $invalid (0,100,-1,'abc','1.5') {
            my $r=Libki::Utils::Printing::release($c,{print_job_id=>1,payment_method=>'cash',copies=>$invalid,expected_amount=>$preview->{amount_due}});
            is($r->{error},'INVALID_COPIES','invalid quantity rejected');
            is($$status,'Held','invalid quantity leaves job held');
        }
        my $stale=Libki::Utils::Printing::release($c,{print_job_id=>1,payment_method=>'cash',copies=>3,expected_amount=>'0.01'});
        is($stale->{error},'PRINT_COST_CHANGED','stale quote rejected');
        is($job->copies,1,'stale price does not change copies');
        my $r=Libki::Utils::Printing::release($c,{print_job_id=>1,payment_method=>'cash',copies=>3,expected_amount=>$preview->{amount_due}});
        ok($r->{success},'reviewed three-copy job released');
        is($job->copies,3,'copy count saved with claim');
        my $retry=Libki::Utils::Printing::release($c,{print_job_id=>1,payment_method=>'cash',copies=>3,expected_amount=>$preview->{amount_due}});
        ok(!$retry->{success},'duplicate release blocked');
        is(scalar(grep {$_->{action} eq 'PRINT_PAYMENT_CASH'} @$stats),1,'cash audited only once');
        my $options=Libki::Utils::Printing::cups_job_options($job,{});
        is($options->{copies},3,'CUPS receives copy count in one job');
    }
};


subtest 'Reprint quantity preserves source and repeated request creates one job' => sub {
    my ($patron)=build_mock_user(funds=>0);
    my ($staff)=build_mock_user(id=>99,username=>'test.staff');
    my $file=build_mock_print_file(pages=>1);
    my ($source)=build_mock_print_job(id=>1,type=>'cups',status=>'Done',copies=>1,user_obj=>$patron,print_file=>$file);
    my ($created)=build_mock_print_job(id=>2,type=>'cups',status=>'Held',copies=>16,user_obj=>$patron,print_file=>$file);
    my ($c,$stats,$jobs)=build_mock_c(user=>$patron,c_user=>$staff,print_job=>$source,created_print_job=>$created,
        print_file=>$file,is_admin=>1,printer_config=>{staff_print_release=>'enabled',printers=>{printer1=>{cost_per_page=>0.15}}});
    my $params={print_job_id=>1,copies=>16,expected_amount=>'2.40',request_id=>'00000000-0000-0000-0000-000000000001'};
    my $r=Libki::Utils::Printing::create_reprint_job($c,$params);
    ok($r->{success},'16-copy reprint created');
    is($jobs->[0]{copies},16,'copies saved in new job');
    is($source->copies,1,'source remains unchanged');
    my $retry=Libki::Utils::Printing::create_reprint_job($c,$params);
    ok($retry->{success},'same request retrieves existing job');
    is($retry->{reprint_job_id},2,'same job ID');
    is(scalar(@$jobs),1,'duplicate request creates only one job');
};

done_testing();
