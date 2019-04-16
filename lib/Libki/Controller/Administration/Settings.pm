package Libki::Controller::Administration::Settings;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::Settings - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 auto

=cut 

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->assert_user_roles( qw/superadmin/ );    
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;
    my @timeallowance;
    my @timesession;
    my $settings = $c->model('DB::Setting')->search({ instance => $instance });
    my @locations = $c->model('DB::Client')->search(
         {
             instance => $instance,
         },
         {
             columns  => [qw/location/],
             distinct => 1
         }
     )->get_column('location')->all();

    while ( my $s = $settings->next() ) {
        $c->stash( $s->name => $s->value );
    }
    foreach my $location (@locations){
        my $nameallowance = "DefaultTimeAllowance$location";
        my $namesession = "DefaultSessionTimeAllowance$location";
        my $time_location = ($c->model('DB::Setting')->find({ instance => $instance, name => $nameallowance })) ? $c->model('DB::Setting')->find({ instance => $instance, name => $nameallowance })->value : $c->model('DB::Setting')->find({ instance => $instance, name => "DefaultTimeAllowance" })->value;
        my $time_session = ($c->model('DB::Setting')->find({ instance => $instance, name => $namesession })) ? $c->model('DB::Setting')->find({ instance => $instance, name => $namesession })->value : $c->model('DB::Setting')->find({     instance => $instance, name => "DefaultSessionTimeAllowance" })->value;
        my $row = {
            name => $nameallowance,
            location => "$location",
            time => $time_location
        };
        push @timeallowance, $row;
        $row = {
            name => $namesession,
            location => "$location",
            time => $time_session
        };
        push @timesession, $row;
    }
    $c->stash(
        timeallowanceperlocation => \@timeallowance,
        timesessionallowanceperlocation => \@timesession,

    );
}

=head2 update

=cut

sub update :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $instance = $c->instance;

    foreach my $setting ( keys %{$c->request->params} ) {
        my $value = $c->request->params->{ $setting };

        $c->model('DB::Setting')->update_or_create(
            {
                instance => $instance,
                name     => $setting,
                value    => $value,
            }
        );
    }

    # ReservationShowUsername is a checkbox
    $c->model('DB::Setting')->update_or_create(
        {
            instance => $instance,
            name     => 'ReservationShowUsername',
            value    => ( $c->request->params->{ReservationShowUsername} // 0 ) eq 'on' ? 1 : 0,
        }
    );
    
    $c->response->redirect( $c->uri_for( $self->action_for('index') ) );
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut

=head1 LICENSE

This file is part of Libki.

Libki is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as 
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

Libki is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Libki.  If not, see <http://www.gnu.org/licenses/>.

=cut

__PACKAGE__->meta->make_immutable;

1;
