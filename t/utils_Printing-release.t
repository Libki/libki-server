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

    # Mock DB model (for txn_do — just runs the sub immediately)
    my $db_model = Test::MockObject->new();
    $db_model->mock( 'txn_do', sub { my ( $self, $code ) = @_; $code->(); } );

    # Mock print job result set
    my $print_job_rs = Test::MockObject->new();
    $print_job_rs->mock( 'find', sub {
        return $opts{print_job};
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

    return ( $c, \@created_statistics );
}

# Helper to build a mock user object
sub build_mock_user {
    my (%opts) = @_;

    my $_funds                = $opts{funds}                // 10.00;
    my $_gratis_print_balance = $opts{gratis_print_balance} // 0;
    my $_id                   = $opts{id}                   // 1;
    my $_username             = $opts{username}              // 'testuser';
    my $_debit_called         = 0;
    my $_debit_amount         = 0;

    my $user = Test::MockObject->new();
    $user->mock( 'id',       sub { return $_id; } );
    $user->mock( 'username', sub { return $_username; } );
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
        $_debit_called = 1;
        $_debit_amount = $amount;
        $_funds -= $amount;
        return 1;
    });
    $user->mock( 'discard_changes', sub { return; } );
    $user->mock( 'update', sub { return 1; } );

    return ( $user, \$_debit_called, \$_debit_amount, \$_gratis_print_balance );
}

# Helper to build a mock print job
sub build_mock_print_job {
    my (%opts) = @_;

    my $_printer = $opts{printer}  // 'printer1';
    my $_status  = $opts{status}   // 'Held';
    my $_type    = $opts{type}     // 'PrintManager';
    my $_update_called = 0;

    my $pj = Test::MockObject->new();
    $pj->mock( 'id',            sub { return $opts{id} // 1; } );
    $pj->mock( 'user_id',       sub { return $opts{user_id} // 1; } );
    $pj->mock( 'print_file_id', sub { return $opts{print_file_id} // 100; } );
    $pj->mock( 'copies',        sub { return $opts{copies} // 1; } );
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
            $_status = $args->{status} if exists $args->{status};
        }
        return 1;
    });
    $pj->mock( 'print_file', sub { return $opts{print_file}; } );
    $pj->mock( 'user',       sub { return $opts{user_obj}; } );

    return ( $pj, \$_status, \$_update_called );
}

# Helper to build a mock print file
sub build_mock_print_file {
    my (%opts) = @_;
    my $pf = Test::MockObject->new();
    $pf->mock( 'id',       sub { return $opts{id}       // 100; } );
    $pf->mock( 'pages',    sub { return $opts{pages}    // 5; } );
    $pf->mock( 'filename', sub { return $opts{filename} // 'test.pdf'; } );
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

done_testing();
