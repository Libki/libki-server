package Libki::Controller::Administration::API::User;

use Moose;
use String::Random qw(random_string);

use namespace::autoclean;

use Encode qw(decode encode);

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

    my $user = $c->model('DB::User')->find($id);

    my $enc = 'UTF-8';

    my $roles = $user->roles;
    my @roles;
    while ( my $role = $roles->next() ) {
        push( @roles, $role->role );
    }

    $c->stash(
        {
            'id'              => $user->id,
            'username'        => decode($enc,$user->username),
            'minutes'         => $user->minutes,
            'status'          => $user->status,
            'notes'           => decode($enc,$user->notes),
            'is_troublemaker' => $user->is_troublemaker,
            'roles'           => \@roles,
        }
    );

    $c->forward( $c->view('JSON') );
}

=head2 create

=cut

sub create : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    my $params = $c->request->params;

    my $username = $params->{'username'};
    my $password = $params->{'password'};
    my $minutes  = $params->{'minutes'}
      || $c->model('DB::Setting')->find( { instance => $instance, name => 'DefaultTimeAllowance' } )->value;

    $minutes = 0 if ( $minutes < 0 );

    my $success = 0;

    my $user = $c->model('DB::User')->create(
        {
            instance          => $instance,
            username          => $username,
            password          => $password,
            minutes_allotment => $minutes,
            status            => 'enabled',
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

    my $instance = $c->request->headers->{'libki-instance'};

    my $params = $c->request->params;

    my $current_guest_number_setting =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'CurrentGuestNumber' });
    my $current_guest_number = $current_guest_number_setting->value + 1;
    $current_guest_number_setting->set_column( 'value', $current_guest_number );
    $current_guest_number_setting->update();

    my $prefix_setting = $c->model('DB::Setting')->find('GuestPassPrefix');
    my $prefix = $prefix_setting && $prefix_setting->value ? $prefix_setting->value : 'guest';

    my $username = $prefix . $current_guest_number;
    my $password =
      random_string("nnnn");    #TODO: Make the pattern a system setting
    my $minutes = $c->model('DB::Setting')->find({ instance => $instance, name => 'DefaultGuestSessionTimeAllowance' })->value;

    my $success = 0;

    my $user = $c->model('DB::User')->create(
        {
            instance          => $instance,
            username          => $username,
            password          => $password,
            minutes_allotment => $minutes,
            status            => 'enabled',
            is_guest          => 'Yes',
        }
    );

    $success = 1 if ($user);

    $c->stash(
        'success'  => $success,
        'username' => $username,
        'password' => $password,
        'minutes'  => $minutes
    );
    $c->forward( $c->view('JSON') );
}

=head2 batch_create_guest

=cut

sub batch_create_guest : Local : Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

    my $params = $c->request->params;

    my $prefix_setting = $c->model('DB::Setting')->find('GuestPassPrefix');
    my $prefix = $prefix_setting && $prefix_setting->value ? $prefix_setting->value : 'guest';

    my $success = 0;

    my $guest_count =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'GuestBatchCount' })->value();
    my $batch_guest_pass_username_label =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'BatchGuestPassUsernameLabel' })->value();
    my $batch_guest_pass_password_label =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'BatchGuestPassPasswordLabel' })->value();
    my $minutes =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'DefaultGuestSessionTimeAllowance' })->value();
    my $guest_pass_file =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'GuestPassFile' })->value();
    my $current_guest_number_setting =
      $c->model('DB::Setting')->find({ instance => $instance, name => 'CurrentGuestNumber' });

    my $current_guest_number = $current_guest_number_setting->value();

    $current_guest_number++;

    my $file_contents = q{};

    $file_contents .= "\n\n\n";

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
                minutes_allotment => $minutes,
                status            => 'enabled',
                is_guest          => 'Yes'
            }
        );

        $file_contents .= $batch_guest_pass_username_label . $username . "\n\n";
        $file_contents .= $batch_guest_pass_password_label . $password . "\n";
        $file_contents .= "\n\n\n";

        $success = $success + 1 if ($user);
    }

    open( my $fh_guest, '>', $guest_pass_file );
    print $fh_guest $file_contents;
    close $fh_guest;

    $current_guest_number_setting->value($current_guest_number);
    $current_guest_number_setting->update();

    $c->stash(
        'success'  => $success,
        'highest'  => $current_guest_number,
        'number'   => $guest_count,
        'minutes'  => $minutes,
        'contents' => $file_contents,
    );

    $c->forward( $c->view('JSON') );
}

=head2 update

=cut

sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $success = 0;

    my $id      = $c->request->params->{'id'};
    my $minutes = $c->request->params->{'minutes'};
    my $notes   = $c->request->params->{'notes'};
    my $status  = $c->request->params->{'status'};
    my @roles   = $c->request->params->{'roles'} || [];

    # For some reason the list of checkboxes are created
    # as a list within a list if multiple are checked
    @roles = @{$roles[0]} if ref( $roles[0] ) eq 'ARRAY';

    $minutes = 0 if ( $minutes < 0 );

    my $user = $c->model('DB::User')->find($id);

    $user->set_column( 'minutes', $minutes );
    $user->set_column( 'notes',   $notes );
    $user->set_column( 'status',  $status );

    if ( $user->update() ) {
        $success = 1;
    }

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

    my $user    = $c->model('DB::User')->find($id);
    my $success = 0;

    if ( $user->delete() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
    $c->forward( $c->view('JSON') );
}

=head2 is_username_unique

=cut

sub is_username_unique : Local : Args(1) {
    my ( $self, $c, $username ) = @_;

    my $instance = $c->request->headers->{'libki-instance'};

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
    my $success = 0;

    my $user = $c->model('DB::User')->find($id);

    my $is_troublemaker = ( $user->is_troublemaker eq 'Yes' ) ? 'No' : 'Yes';

    $user->set_column( 'is_troublemaker', $is_troublemaker );

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
    my $success = 0;

    my $id       = $c->request->params->{'id'};
    my $password = $c->request->params->{'password'};

    my $user = $c->model('DB::User')->find($id);

    $user->set_column( 'password', $password );

    if ( $user->update() ) {
        $success = 1;
    }

    $c->stash( 'success' => $success );
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
