package Libki::Utils::User;

use Modern::Perl;

use Carp;

use String::Random qw(random_string);

=head2 create_or_update_user

Create a user with the given criterea.
If the username exists, that user will be updated instead.

=cut

sub create_or_update_user {
    my ( $c, $params ) = @_;

    my $instance        = $params->{instance} || $c->instance;
    my $username        = $params->{username};
    my $password        = $params->{password};
    my $firstname       = $params->{firstname};
    my $lastname        = $params->{lastname};
    my $category        = $params->{category};
    my $creation_source = $params->{creation_source} || 'local';
    my $status          = $params->{status} || 'enabled';
    my $minutes         = $params->{minutes} || undef;
    my $is_admin        = $params->{admin};
    my $is_superadmin   = $params->{superadmin};

    confess "No username passed" unless $username;
    confess "No password passed" unless $password;

    my $schema  = $c->schema;
    my $user_rs = $schema->resultset('User');

    my $now = $c->now();

    my $default_time_allowance_setting = $schema->resultset('Setting')
        ->find( { instance => $instance, name => 'DefaultTimeAllowance' } );
    my $default_time_allowance
        = $default_time_allowance_setting ? $default_time_allowance_setting->value : 0;

    my $user;
    $schema->txn_do(
        sub {
            $user
                = $user_rs->search( { instance => $instance, username => $username } )->next();

            if ($user) {
                $user->set_column( 'password', $password );
                $user->update(
                    {
                        password   => $password,
                        updated_on => $now,
                    }
                );
            }
            else {
                $user = $user_rs->create(
                    {
                        instance        => $instance,
                        username        => $username,
                        password        => $password,
                        category        => $category,
                        firstname       => $firstname,
                        lastname        => $lastname,
                        status          => 'enabled',
                        creation_source => 'local',
                        is_troublemaker => 'No',
                        created_on      => $now,
                        updated_on      => $now,
                    }
                );

            }

            if ( defined $minutes ) {
                $c->model('DB::Allotment')->update_or_create(
                    {
                        instance => $user->instance,
                        user_id  => $user->id,
                        location => '',
                        minutes  => $minutes,
                    }
                );
            }

            if ($is_superadmin) {
                my $role = $schema->resultset('Role')->search( { role => 'superadmin' } )->single();

                $schema->resultset('UserRole')->update_or_create(
                    {
                        role_id => $role->id,
                        user_id => $user->id,
                    }
                );
            }

            if ( $is_admin || $is_superadmin ) {
                my $role = $schema->resultset('Role')->search( { role => 'admin' } )->single();

                $schema->resultset('UserRole')->update_or_create(
                    {
                        role_id => $role->id,
                        user_id => $user->id,
                    }
                );
            }
        }
    );

    return $user;
}

=head2 create_guest

Create a guest account with the given category.
If $client is passed, minutes will be set for that client type.

=cut

sub create_guest {
    my ( $c, $category, $client ) = @_;

    my $instance = $c->instance;

    my $now = $c->now();

    my ( $user, $password, $minutes_allotment );
    $c->model('DB')->txn_do(
        sub {

            my $current_guest_number_setting = $c->model('DB::Setting')
                ->find_or_new( { instance => $instance, name => 'CurrentGuestNumber' } );

            my $current_guest_number
                = $current_guest_number_setting->value
                ? $current_guest_number_setting->value + 1
                : 1;
            $current_guest_number_setting->set_column( 'value', $current_guest_number );
            $current_guest_number_setting->update_or_insert();

            my $prefix_setting = $c->setting('GuestPassPrefix');
            my $prefix         = $prefix_setting || 'guest';

            my $username = $prefix . $current_guest_number;
            $password = random_string("nnnn");    #TODO: Make the pattern a system setting

            $user = $c->model('DB::User')->create(
                {
                    instance        => $instance,
                    username        => $username,
                    password        => $password,
                    status          => 'enabled',
                    is_guest        => 'Yes',
                    created_on      => $now,
                    updated_on      => $now,
                    category        => $category,
                    creation_source => 'local',
                }
            );

            $minutes_allotment = $c->setting('DefaultGuestTimeAllowance');
            $minutes_allotment = 0 unless $minutes_allotment > 0;

            # If created from the client login as guest button, we can give a more accurate number
            $minutes_allotment = $user->minutes( $c, $client ) if $client;

        }
    );

    return ( $user, $password, $minutes_allotment );
}

1;
