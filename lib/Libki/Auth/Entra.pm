package Libki::Auth::Entra;

use strict;
use warnings;

use Carp qw(croak);

=head1 NAME

Libki::Auth::Entra - map verified single-tenant identities to Libki staff accounts

=head1 METHODS

=head2 authorization_from_claims

Authorize claims already verified by OIDC::Client. This does not verify JWTs.
Names and email are display attributes, never authorization criteria.

=cut

sub authorization_from_claims {
    my ( $class, $claims, $config ) = @_;

    return _deny('invalid_claims') unless ref($claims) eq 'HASH';
    return _deny('invalid_config') unless ref($config) eq 'HASH';

    my $expected_tenant = lc( $config->{tenant_id} // q{} );
    my $tenant_id       = lc( $claims->{tid}       // q{} );
    return _deny('tenant_mismatch')
        unless _is_uuid($expected_tenant) && $tenant_id eq $expected_tenant;

    my $oid = lc( $claims->{oid} // q{} );
    return _deny('missing_object_id') unless _is_uuid($oid);

    my @app_roles = _claim_values( $claims->{roles} );
    my @groups    = map { lc($_) } _claim_values( $claims->{groups} );

    my $admin_role = $config->{admin_app_role} // q{};
    my $staff_role = $config->{staff_app_role} // q{};
    my $admin_group = lc( $config->{admin_group_id} // q{} );
    my $staff_group = lc( $config->{staff_group_id} // q{} );

    my $is_admin_role = length($admin_role) && grep { $_ eq $admin_role } @app_roles;
    my $is_staff_role = length($staff_role) && grep { $_ eq $staff_role } @app_roles;
    my $is_admin_group = _is_uuid($admin_group) && grep { $_ eq $admin_group } @groups;
    my $is_staff_group = _is_uuid($staff_group) && grep { $_ eq $staff_group } @groups;

    my $uses_group_fallback = _is_uuid($admin_group) || _is_uuid($staff_group);
    my $has_group_overage
        = ref( $claims->{_claim_names} ) eq 'HASH'
        && exists $claims->{_claim_names}->{groups};
    $has_group_overage ||= $claims->{hasgroups};

    return _deny('group_overage')
        if !$is_admin_role && !$is_staff_role
        && $uses_group_fallback && $has_group_overage;

    my $is_admin = $is_admin_role || $is_admin_group;
    my $is_staff = $is_staff_role || $is_staff_group;
    return _deny('not_assigned') unless $is_admin || $is_staff;

    my $firstname = _clean_text( $claims->{given_name}, 191 );
    my $lastname  = _clean_text( $claims->{family_name}, 191 );
    my $display_name = _clean_text( $claims->{name}, 191 );
    $display_name ||= join q{ }, grep { length } ( $firstname, $lastname );
    $display_name ||= _clean_text( $claims->{preferred_username}, 191 );
    $display_name ||= 'Entra staff';

    my $email = _clean_text( $claims->{email}, 191 );
    if ( !length($email) ) {
        my $preferred = _clean_text( $claims->{preferred_username}, 191 );
        $email = $preferred if $preferred =~ /\A[^\s\@]+\@[^\s\@]+\z/;
    }

    return {
        authorized           => 1,
        tenant_id            => $tenant_id,
        oid                  => $oid,
        username             => "entra-$oid",
        firstname            => $firstname,
        lastname             => $lastname,
        display_name         => $display_name,
        email                => $email,
        role_level           => $is_admin ? 'admin' : 'staff',
        libki_roles          => $is_admin ? [qw/admin superadmin/] : [qw/admin/],
        authorization_source => ( $is_admin_role || $is_staff_role )
            ? 'app_role'
            : 'group',
    };
}

=head2 sync_user

Create or reconcile an Entra-owned staff account in the current instance.
Keep disabled accounts disabled and refuse to overwrite a local account.

=cut

sub sync_user {
    my ( $class, $c, $decision ) = @_;

    croak 'Entra decision is not authorized'
        unless ref($decision) eq 'HASH' && $decision->{authorized};

    my $instance = $c->instance;
    my $username = $decision->{username};
    my $user;

    $c->model('DB')->txn_do(
        sub {
            $user = $c->model('DB::User')->find(
                {
                    instance => $instance,
                    username => $username,
                }
            );

            if ($user) {
                my $source = $user->creation_source // q{};
                croak "Refusing to replace non-Entra account '$username'"
                    if $source ne 'entra';

                croak 'Entra account is locally disabled'
                    unless ( $user->status // q{} ) eq 'enabled';

                $user->update(
                    {
                        firstname      => $decision->{firstname},
                        lastname       => $decision->{lastname},
                        updated_on     => $c->now,
                        creation_source => 'entra',
                    }
                );
            }
            else {
                require Crypt::PRNG;
                my $unusable_password = Crypt::PRNG::random_bytes_b64u(48);
                $user = $c->model('DB::User')->create(
                    {
                        instance        => $instance,
                        username        => $username,
                        password        => $unusable_password,
                        firstname       => $decision->{firstname},
                        lastname        => $decision->{lastname},
                        status          => 'enabled',
                        created_on      => $c->now,
                        updated_on      => $c->now,
                        creation_source => 'entra',
                    }
                );
            }

            my %wanted = map { $_ => 1 } @{ $decision->{libki_roles} };
            for my $role_name (qw/admin superadmin/) {
                my $role = $c->model('DB::Role')->find( { role => $role_name } )
                    or croak "Required Libki role '$role_name' does not exist";

                if ( $wanted{$role_name} ) {
                    $c->model('DB::UserRole')->find_or_create(
                        {
                            user_id => $user->id,
                            role_id => $role->id,
                        }
                    );
                }
                else {
                    $c->model('DB::UserRole')->search(
                        {
                            user_id => $user->id,
                            role_id => $role->id,
                        }
                    )->delete;
                }
            }
        }
    );

    return $c->model('DB::User')->find(
        {
            instance => $instance,
            username => $username,
        }
    );
}

=head2 is_shadow_username

Identify the reserved Entra username namespace used to block password login.

=cut

sub is_shadow_username {
    my ( $class, $username ) = @_;
    return defined($username)
        && $username =~ /\Aentra-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i;
}

sub _claim_values {
    my ($value) = @_;
    return () unless defined $value;
    return grep { defined($_) && !ref($_) && length($_) } @{$value}
        if ref($value) eq 'ARRAY';
    return ref($value) ? () : ($value);
}

sub _clean_text {
    my ( $value, $maximum_length ) = @_;
    return q{} if !defined($value) || ref($value);
    $value =~ s/[\x00-\x1f\x7f]+/ /g;
    $value =~ s/\A\s+|\s+\z//g;
    $value =~ s/\s+/ /g;
    return substr( $value, 0, $maximum_length );
}

sub _is_uuid {
    my ($value) = @_;
    return defined($value)
        && $value =~ /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i;
}

sub _deny {
    my ($reason) = @_;
    return {
        authorized => 0,
        reason     => $reason,
    };
}

1;