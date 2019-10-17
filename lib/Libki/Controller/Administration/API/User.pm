package Libki::Controller::Administration::API::User;

use Moose;
use String::Random qw(random_string);

use namespace::autoclean;

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

    my $user = $c->model('DB::User')->find({ instance => $instance, id => $id });

    my $roles = $user->roles;
    my @roles;
    while ( my $role = $roles->next() ) {
        push( @roles, $role->role );
    }

    $c->stash(
        {
            id              => $user->id,
            username        => $user->username,
            firstname       => $user->firstname,
            lastname        => $user->lastname,
            category        => $user->category,
            minutes         => $user->minutes_allotment,
            status          => $user->status,
            notes           => $user->notes,
            is_troublemaker => $user->is_troublemaker,
            roles           => \@roles,
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
    my $minutes   = $params->{minutes};

    my $success = 0;

    my $now = $c->now();
    my $user = $c->model('DB::User')->create(
        {
            instance          => $instance,
            username          => $username,
            firstname         => $firstname,
            lastname          => $lastname,
            category          => $category,
            password          => $password,
            minutes_allotment => $minutes,
            status            => 'enabled',
            created_on        => $now,
            updated_on        => $now,
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

    my $params = $c->request->params;

    my $current_guest_number_setting = $c->model('DB::Setting')->find({ instance => $instance, name => 'CurrentGuestNumber' });
    my $current_guest_number = $current_guest_number_setting->value + 1;
    $current_guest_number_setting->set_column( 'value', $current_guest_number );
    $current_guest_number_setting->update();

    my $prefix_setting = $c->setting('GuestPassPrefix');
    my $prefix = $prefix_setting || 'guest';

    my $username = $prefix . $current_guest_number;
    my $password =
      random_string("nnnn");    #TODO: Make the pattern a system setting

    my $minutes_allotment = $c->setting('DefaultGuestTimeAllowance');
    $minutes_allotment = 0 unless $minutes_allotment > 0;

    my $success = 0;

    my $now = $c->now();
    my $user = $c->model('DB::User')->create(
        {
            instance          => $instance,
            username          => $username,
            password          => $password,
            minutes_allotment => $minutes_allotment,
            status            => 'enabled',
            is_guest          => 'Yes',
            created_on        => $now,
            updated_on        => $now,
        }
    );

    $success = 1 if ($user);

    $c->stash(
        'success'  => $success,
        'username' => $username,
        'password' => $password,
        'minutes'  => $minutes_allotment,
    );
    $c->forward( $c->view('JSON') );
}

=head2 batch_create_guest

=cut

sub batch_create_guest : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $instance = $c->instance;

    my $params = $c->request->params;

    my $prefix_setting = $c->setting('GuestPassPrefix');
    my $prefix = $prefix_setting || 'guest';

    my $success = 0;

    my $BatchGuestPassCustomCSS = $c->setting('BatchGuestPassCustomCSS');

    my $guest_count = $c->setting('GuestBatchCount') || 10;
    my $batch_guest_pass_username_label = $c->setting('BatchGuestPassUsernameLabel');
    my $batch_guest_pass_password_label = $c->setting('BatchGuestPassPasswordLabel');

    my $minutes_allotment = $c->setting('DefaultGuestTimeAllowance');
    $minutes_allotment = 0 unless ( $minutes_allotment > 0 );

    my $current_guest_number_setting =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'CurrentGuestNumber' });
    my $current_guest_number = $current_guest_number_setting->value() + 1;

    my $file_contents = q{};

    $file_contents .= "<html><head><style>$BatchGuestPassCustomCSS</style></head><body>";

    my $now = $c->now();

    for ( my $i = 0 ; $i < $guest_count ; $i++ ) {

        $current_guest_number = $current_guest_number + 1;
        my $username = $prefix . $current_guest_number;
        my $password =
          random_string("nnnn");    #TODO: Make the pattern a system setting

        my $user = $c->model('DB::User')->create(
            {
                instance          => $instance,
                username          => $username,
                password          => $password,
                minutes_allotment => $minutes_allotment,
                status            => 'enabled',
                is_guest          => 'Yes',
                created_on        => $now,
                updated_on        => $now,
            }
        );

        $file_contents .= "\n<span class='guest-pass'>";
        $file_contents .= "\n<span class='guest-pass-username'>";
        $file_contents .= "<span class='guest-pass-username-label'>$batch_guest_pass_username_label</span><span class='guest-pass-username-content'>$username</span>";
        $file_contents .= "</span>";
        $file_contents .= "\n\n<span class='guest-pass-password'>";
        $file_contents .= "<span class='guest-pass-password-label'>$batch_guest_pass_password_label</span><span class='guest-pass-password-content'>$password</span>\n\n";
        $file_contents .= "</span>";
        $file_contents .= "</body>";

        $success = $success + 1 if ($user);
    }

    $current_guest_number_setting->value($current_guest_number);
    $current_guest_number_setting->update();

    $c->stash(
        'success'  => $success,
        'highest'  => $current_guest_number,
        'number'   => $guest_count,
        'minutes'  => $minutes_allotment,
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
    my $notes     = $c->request->params->{'notes'};
    my $status    = $c->request->params->{'status'};
    my @roles     = $c->request->params->{'roles'} || [];

    # For some reason the list of checkboxes are created
    # as a list within a list if multiple are checked
    @roles = @{$roles[0]} if ref( $roles[0] ) eq 'ARRAY';

    $minutes = undef if $minutes eq q{};
    $minutes = 0 if defined($minutes) &&  $minutes < 0;

    my $user = $c->model('DB::User')->find({ instance => $instance, id => $id });

    my $now = $c->now();

    $success = 1 if $user->update(
        {

            firstname         => $firstname,
            lastname          => $lastname,
            category          => $category,
            minutes_allotment => $minutes,
            notes             => $notes,
            status            => $status,
            updated_on        => $now,
        }
    );

    if ( $c->check_user_roles(qw/superadmin/) ) {

        # Update the user's roles
        my @libki_roles = $c->model('DB::Role')->search();
        foreach my $lr ( @libki_roles ) {
            my $role = $lr->role;
            if ( grep { /$role/ } @roles ) {
                ## Add the role if it doesn't exists
                $c->model('DB::UserRole')
                  ->find_or_create( { user_id => $id, role_id => $lr->id } );
            }
            else {
                ## Delete the role if it does already exist
                $c->model('DB::UserRole')
                  ->search( { user_id => $id, role_id => $lr->id } )->delete();
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
            if ( $i_am_superadmin || ( $i_am_admin && !$user_is_superadmin ) ) {
                if ( $user->delete() ) {
                    $success = 1;
                }
            }
            elsif ( $i_am_admin && $user_is_superadmin ) {
                $msg = q{ADMIN_CANNOT_DELETE_SUPERADMIN};
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

    my $count =
      $c->model('DB::User')->search( { instance => $instance, username => $username } )->count();

    my $is_unique = ($count) ? 0 : 1;

    $is_unique = 0 if ( $username =~ '^guest' );

    $c->stash( is_unique => $is_unique );

    $c->forward( $c->view('JSON') );
}

=head2 toggle_troublemaker

=cut

sub toggle_troublemaker : Local : Args(1) {
    my ( $self, $c, $id ) = @_;
    my $instance = $c->instance;

    my $success = 0;

    my $user = $c->model('DB::User')->find({ instance => $instance, id => $id });

    my $is_troublemaker = ( $user->is_troublemaker eq 'Yes' ) ? 'No' : 'Yes';

    my $now = $c->now();

    $user->set_column( 'is_troublemaker', $is_troublemaker );
    $user->set_column( 'updated_on', $now );

    if ( $user->update() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 change_password

=cut

sub change_password : Local : Args(0) {
    my ( $self, $c, $id ) = @_;
    my $instance = $c->instance;

    my $success = 0;

    my $id       = $c->request->params->{'id'};
    my $password = $c->request->params->{'password'};

    my $user = $c->model('DB::User')->find({ instance => $instance, id => $id });

    my $now = $c->now();

    my $msg;

    if ($user) {
        my $user_is_superadmin = $user->has_role(q{superadmin});
        my $i_am_superadmin    = $c->user->has_role(qw{superadmin});
        my $i_am_admin         = $c->user->has_role(qw{admin});

        if ( $i_am_admin || $i_am_superadmin ) {
            if ( $i_am_superadmin || ( $i_am_admin && !$user_is_superadmin ) ) {
                $user->set_column( 'password', $password );
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
