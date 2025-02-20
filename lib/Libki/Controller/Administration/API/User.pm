package Libki::Controller::Administration::API::User;

use Moose;

use namespace::autoclean;
use POSIX;

use Libki::Utils::Printing;
use Libki::Utils::User;

use JSON qw(to_json);

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 get

=cut

sub get : Local : Args(1) {
    my ( $self, $c, $id ) = @_;
    my $instance = $c->instance;

    my $user = $c->model('DB::User')->find( { instance => $instance, id => $id } );

    my $roles = $user->roles;
    my @roles;
    while ( my $role = $roles->next() ) {
        push( @roles, $role->role );
    }

    $c->stash(
        {
            id                 => $user->id,
            username           => $user->username,
            firstname          => $user->firstname,
            lastname           => $user->lastname,
            category           => $user->category,
            minutes            => $user->minutes($c),
            status             => $user->status,
            notes              => $user->notes,
            funds              => $user->funds,
            is_troublemaker    => $user->is_troublemaker,
            troublemaker_until => defined( $user->troublemaker_until )
            ? $user->troublemaker_until->strftime('%Y-%m-%d 23:59')
            : undef,
            roles => \@roles,
        }
    );

    $c->forward( $c->view('JSON') );
}

=head2 create

=cut

sub create : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $params = $c->request->params;

    my $username  = $params->{username};
    my $firstname = $params->{firstname};
    my $lastname  = $params->{lastname};
    my $category  = $params->{category};
    my $password  = $params->{password};
    my $minutes   = $params->{minutes} || undef;

    my $success = 0;

    my $now  = $c->now();
    my $user = Libki::Utils::User::create_or_update_user(
        $c,
        {
            instance        => $instance,
            username        => $username,
            firstname       => $firstname,
            lastname        => $lastname,
            category        => $category,
            password        => $password,
            status          => 'enabled',
            created_on      => $now,
            updated_on      => $now,
            creation_source => 'local',
            minutes         => $minutes,
        }
    );

    $success = 1 if ($user);

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 create_guest

=cut

sub create_guest : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;
    my $params   = $c->request->params;

    my $category = $params->{category};

    my ( $user, $password, $minutes_allotment ) = Libki::Utils::User::create_guest( $c, $category );

    $c->stash(
        'success'  => $user ? 1               : 0,
        'username' => $user ? $user->username : q{},
        'password' => $password,
        'category' => $category,
        'minutes'  => $minutes_allotment,
    );
    $c->forward( $c->view('JSON') );
}

=head2 batch_create_guest

=cut

sub batch_create_guest : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $params         = $c->request->params;
    my $category       = $params->{category};
    my $prefix_setting = $c->setting('GuestPassPrefix');
    my $prefix         = $prefix_setting || 'guest';

    my $success = 0;

    my $batch_guest_pass_custom_css = $c->setting('BatchGuestPassCustomCSS');
    my $batch_guest_pass_template   = $c->setting('BatchGuestPassTemplate');

    my $guest_count                     = $c->setting('GuestBatchCount') || 10;
    my $batch_guest_pass_username_label = $c->setting('BatchGuestPassUsernameLabel');
    my $batch_guest_pass_password_label = $c->setting('BatchGuestPassPasswordLabel');

    my $minutes_allotment = $c->setting('DefaultGuestTimeAllowance');
    $minutes_allotment = 0 unless ( $minutes_allotment > 0 );

    my $current_guest_number_setting = $c->model('DB::Setting')
        ->find_or_new( { instance => $instance, name => 'CurrentGuestNumber' } );
    my $current_guest_number
        = $current_guest_number_setting->value ? $current_guest_number_setting->value + 1 : 1;

    my $now = $c->now();

    my $file_contents .= "<html><head><style>$batch_guest_pass_custom_css</style></head><body>";

    my @guests;
    for ( my $i = 0; $i < $guest_count; $i++ ) {

        my ( $user, $password, $minutes_allotment )
            = Libki::Utils::User::create_guest( $c, $category );
        my $username = $user->username;

        $file_contents .= "\n<div class='guest-pass'>";
        $file_contents .= "\n<span class='guest-pass-username'>";
        $file_contents
            .= "<span class='guest-pass-username-label'>$batch_guest_pass_username_label</span><span class='guest-pass-username-content'>$username</span>";
        $file_contents .= "</span>";
        $file_contents .= "\n\n<span class='guest-pass-password'>";
        $file_contents
            .= "<span class='guest-pass-password-label'>$batch_guest_pass_password_label</span><span class='guest-pass-password-content'>$password</span>\n\n";
        $file_contents .= "</span>";
        $file_contents .= "</div>";
        $file_contents .= "</body>";

        push( @guests, { username => $username, password => $password } ) if $user;

        $success = $success + 1 if ($user);
    }

    if ($batch_guest_pass_template) {
        $file_contents = q{};
        my $tt   = Template->new() || die $Template::ERROR;
        my $vars = {
            batch_guest_pass_custom_css     => $batch_guest_pass_custom_css,
            batch_guest_pass_username_label => $batch_guest_pass_username_label,
            batch_guest_pass_password_label => $batch_guest_pass_password_label,
            guests                          => \@guests,
        };
        $tt->process( \$batch_guest_pass_template, $vars, \$file_contents );
    }

    $c->stash(
        'success'  => $success,
        'highest'  => $current_guest_number,
        'number'   => $guest_count,
        'minutes'  => $minutes_allotment,
        'category' => $category,
        'contents' => $file_contents,
    );

    $c->forward( $c->view('JSON') );
}

=head2 update

=cut

sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $success = 0;

    my $id        = $c->request->params->{'id'};
    my $firstname = $c->request->params->{firstname};
    my $lastname  = $c->request->params->{lastname};
    my $category  = $c->request->params->{category};
    my $minutes   = $c->request->params->{'minutes'};
    my $funds     = $c->request->params->{'funds'};
    my $notes     = $c->request->params->{'notes'};
    my $status    = $c->request->params->{'status'};
    my @roles     = $c->request->params->{'roles'} || [];

    # For some reason the list of checkboxes are created
    # as a list within a list if multiple are checked
    @roles = @{ $roles[0] } if ref( $roles[0] ) eq 'ARRAY';

    $minutes = undef if $minutes eq q{};
    $minutes = 0     if defined($minutes) && $minutes < 0;

    my $user = $c->model('DB::User')->find( { instance => $instance, id => $id } );

    my $now = $c->now();

    my $funds_changed = $funds != $user->funds;
    $user->set_funds( $c, $funds ) if $funds_changed;

    $success = 1 if $user->update(
        {

            firstname  => $firstname,
            lastname   => $lastname,
            category   => $category,
            funds      => $funds,
            notes      => $notes,
            status     => $status,
            updated_on => $now,
        }
    );

    if ( defined $minutes ) {
        $c->model('DB::Allotment')->update_or_create(
            {
                instance => $instance,
                user_id  => $user->id,
                location => '',
                minutes  => $minutes,
            }
        );
    }
    else {
        $c->model('DB::Allotment')->search( { instance => $instance, user_id => $user->id } )
            ->delete;
    }

    if ( $c->check_user_roles(qw/superadmin/) ) {

        # Update the user's roles
        my @libki_roles = $c->model('DB::Role')->search();
        foreach my $lr (@libki_roles) {
            my $role = $lr->role;
            if ( grep {/$role/} @roles ) {
                ## Add the role if it doesn't exists
                $c->model('DB::UserRole')->find_or_create( { user_id => $id, role_id => $lr->id } );
            }
            else {
                ## Delete the role if it does already exist
                $c->model('DB::UserRole')->search( { user_id => $id, role_id => $lr->id } )
                    ->delete();
            }
        }
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 delete

=cut

sub delete : Local : Args(1) {
    my ( $self, $c, $id ) = @_;
    my $instance = $c->instance;

    my $user    = $c->model('DB::User')->find( { instance => $instance, id => $id } );
    my $success = 0;

    my $msg;
    if ($user) {
        my $user_is_superadmin = $user->has_role(q{superadmin});
        my $i_am_superadmin    = $c->user->has_role(qw{superadmin});
        my $i_am_admin         = $c->user->has_role(qw{admin});

        if ( $i_am_admin || $i_am_superadmin ) {
            if ( $user->username eq $c->user->username ) {
                $msg = q{CANNOT_DELETE_YOURSELF};
            }
            elsif ( $user_is_superadmin && !$i_am_superadmin ) {
                $msg = q{ADMIN_CANNOT_DELETE_SUPERADMIN};
            }
            elsif ( $i_am_superadmin || ( $i_am_admin && !$user_is_superadmin ) ) {
                $c->model('DB')->txn_do(
                    sub {
                        if ( $user->delete() ) {
                            $success = 1;

                            $c->model('DB::Statistic')->create(
                                {
                                    instance   => $instance,
                                    username   => $user->username,
                                    action     => 'USER_DELETE',
                                    created_on => $c->now,
                                    info       => to_json(
                                        {
                                            deleted_from   => 'Administration/API/User',
                                            user_id        => $user->id,
                                            admin_id       => $c->user->id,
                                            admin_username => $c->user->username,
                                        }
                                    ),
                                }
                            );
                        }
                    }
                );
            }
        }
        else {
            $msg = q{NOT_ADMIN_CANNOT_DELETE_USER};
        }
    }

    $c->stash( 'success' => $success );
    $c->stash( 'message' => $msg );
    $c->forward( $c->view('JSON') );
}

=head2 is_username_unique

=cut

sub is_username_unique : Local : Args(1) {
    my ( $self, $c, $username ) = @_;
    my $instance = $c->instance;

    my $count = $c->model('DB::User')->search( { instance => $instance, username => $username } )
        ->count();

    my $is_unique = ($count) ? 0 : 1;

    $is_unique = 0 if ( $username =~ '^guest' );

    $c->stash( is_unique => $is_unique );

    $c->forward( $c->view('JSON') );
}

=head2 toggle_troublemaker

=cut

sub toggle_troublemaker : Local : Args(3) {
    my ( $self, $c, $id, $until, $notes ) = @_;
    my $instance = $c->instance;

    my $success = 0;

    my $user = $c->model('DB::User')->find( { instance => $instance, id => $id } );

    my $is_troublemaker = ( $user->is_troublemaker eq 'Yes' ) ? 'No' : 'Yes';

    my $now = $c->now();

    $user->set_column( 'is_troublemaker',    $is_troublemaker );
    $user->set_column( 'updated_on',         $now );
    $user->set_column( 'troublemaker_until', undef );
    if ( $until != 0 && $is_troublemaker eq 'Yes' ) {
        my $troublemaker_until = $now->clone;
        $troublemaker_until->add( days => $until );

        $user->set_column( 'troublemaker_until', $troublemaker_until );
        $user->set_column( 'notes',              $notes eq '' ? undef : $notes );
    }

    if ( $user->update() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 change_password

=cut

sub change_password : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $success = 0;

    my $id       = $c->request->params->{'id'};
    my $password = $c->request->params->{'password'};

    my $user = $c->model('DB::User')->find( { instance => $instance, id => $id } );

    my $now = $c->now();

    my $msg;

    if ($user) {
        my $user_is_superadmin = $user->has_role(q{superadmin});
        my $i_am_superadmin    = $c->user->has_role(qw{superadmin});
        my $i_am_admin         = $c->user->has_role(qw{admin});

        if ( $i_am_admin || $i_am_superadmin ) {
            if ( $i_am_superadmin || ( $i_am_admin && !$user_is_superadmin ) ) {
                $user->set_column( 'password',   $password );
                $user->set_column( 'updated_on', $now );

                if ( $user->update() ) {
                    $success = 1;
                }
            }
            elsif ( $i_am_admin && $user_is_superadmin ) {
                $msg = q{ADMIN_CANNOT_CHANGE_SUPERADMIN_PASSWORD};
            }
        }
        else {
            $msg = q{NOT_ADMIN_CHANGE_PASSWORD};
        }
    }

    $c->stash( 'success' => $success );
    $c->stash( 'message' => $msg );
    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info> 

=cut

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.   

=cut

__PACKAGE__->meta->make_immutable;

1;
