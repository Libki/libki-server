package Libki::Controller::Administration::jqGrid;
use Moose;
use namespace::autoclean;

with 'Catalyst::TraitFor::Controller::jQuery::jqGrid';

BEGIN {extends 'Catalyst::Controller::REST'; }

=head1 NAME

LibkiServer::Controller::Admin::jqGrid

=head1 DESCRIPTION

This controller is written to handle Ajax calls made by jqGrid.

Though it uses Catalyst::Controller::REST, it is not actually RESTful.

=head1 METHODS

=cut

sub users : Local : ActionClass('REST') { }

sub users_GET {
    my ( $self, $c ) = @_;

    my $search_fields;
    my $params = $c->request->params;  
    
    $search_fields->{'username'} = { -like => $params->{'username'} . '%' } if ( defined $params->{'username'} );
    $search_fields->{'notes'} = { -like => '%' . $params->{'notes'} . '%' } if ( defined $params->{'notes'} );
    $search_fields->{'name'} = { -like => $params->{'name'} . '%' } if ( defined $params->{'clientname'} );

    my $user_rs = $c->model('DB::User')->search( $search_fields, { prefetch => { session => 'client' } } );
    $user_rs = $self->jqgrid_page( $c, $user_rs );

    my $row = 0;
    my @row_data;
    
    while ( my $user = $user_rs->next() ) {
        my $user_id = $user->id;
        
        my @cell;
        push( @cell, $user->id );
        push( @cell, $user->username );
        push( @cell, $user->password );
        push( @cell, $user->minutes );
        push( @cell, $user->status );
        push( @cell, $user->message );
        push( @cell, $user->notes );
        push( @cell, $user->is_troublemaker );
        push( @cell, defined( $user->session ) ? $user->session->client->id : undef );
        push( @cell, defined( $user->session ) ? $user->session->client->name : undef );
        push( @cell, defined( $user->session ) ? $user->session->status : undef );
        my $single_row = {
            cell => \@cell
        };
        push( @row_data, $single_row );
    }
    
    $self->status_ok(
        $c,
        entity => {
            page => $c->stash->{json_data}->{page},
            total => $c->stash->{json_data}->{total},
            records => $c->stash->{json_data}->{records},
            rows => \@row_data
        }
    );
}

sub users_POST {
    my ( $self, $c ) = @_;
    
    my $params = $c->request->params;
    my $users_rs = $c->model('DB::User');

    
    my $op = $params->{'oper'};
    $c->log->debug("Operation is '$op'");

    if ( $op eq 'add' ) {
        $c->log->debug('Adding new user');
        ## Create new user

        my $fields;
        $fields->{'username'} = $params->{'username'} if ( defined $params->{'username'} );
        $fields->{'password'} = $params->{'password'} if ( defined $params->{'password'} );
        $fields->{'minutes'} = $params->{'minutes'} if ( defined $params->{'minutes'} );
        $fields->{'status'} = $params->{'status'} if ( defined $params->{'status'} );
        $fields->{'message'} = $params->{'message'} if ( defined $params->{'message'} );
        $fields->{'notes'} = $params->{'notes'} if ( defined $params->{'notes'} );
        $fields->{'is_troublemaker'} = ( $params->{'is_troublemaker'} eq 'on' ) ? 'Yes' : 'No' if ( defined $params->{'is_troublemaker'} );

        my $new_user = $users_rs->create( $fields );
        
        $self->status_ok(
            $c,
            entity => {
            }
        );

    } elsif ( $op eq 'edit' ) { 
        $c->log->debug('Edit existing user');
        ## Edit existing user
        my $user_id = $params->{'id'};

        my $user = $users_rs->find( { id => $user_id } );

        my $fields;
        $fields->{'username'} = $params->{'username'} if ( defined $params->{'username'} );
        $fields->{'password'} = $params->{'password'} if ( defined $params->{'password'} );
        $fields->{'minutes'} = $params->{'minutes'} if ( defined $params->{'minutes'} );
        $fields->{'status'} = $params->{'status'} if ( defined $params->{'status'} );
        $fields->{'message'} = $params->{'message'} if ( defined $params->{'message'} );
        $fields->{'notes'} = $params->{'notes'} if ( defined $params->{'notes'} );
        $fields->{'is_troublemaker'} = $params->{'is_troublemaker'} if ( defined $params->{'is_troublemaker'} );
    
        $user->update( $fields );

        $self->status_ok(
            $c,
            entity => {
            }
        );
    } elsif ( $op eq 'del' ) {
        $c->log->debug('Deleting existing user');
        ## Delete existing user
        my $user_id = $params->{'id'};
        $users_rs->find( { id => $user_id } )->delete();
        
        $self->status_ok(
            $c,
            entity => {
            }
        );
        
    } else {
        ## No operation given
        $c->log->debug('No operation given');
    }

}

sub clients : Local : ActionClass('REST') { }

sub clients_GET {
    my ( $self, $c ) = @_;

    my $search_fields;
    my $params = $c->request->params;

#    $search_fields->{'username'} = { -like => $params->{'username'} . '%' } if ( defined $params->{'username'} );
#    $search_fields->{'notes'} = { -like => '%' . $params->{'notes'} . '%' } if ( defined $params->{'notes'} );
     $search_fields->{'name'} = { -like => $params->{'name'} . '%' } if ( defined $params->{'name'} );
     $search_fields->{'location'} = { -like => $params->{'location'} . '%' } if ( defined $params->{'location'} );
     $search_fields->{'username'} = { -like => '%' . $params->{'username'} . '%' } if ( defined $params->{'username'} );

    my $client_rs = $c->model('DB::Client')->search( $search_fields, { prefetch => { session => 'user' } } );
    $client_rs = $self->jqgrid_page( $c, $client_rs );

    my $row = 0;
    my @row_data;
    
    while ( my $client = $client_rs->next() ) {
        my $client_id = $client->id;
        
        my @cell;
        push( @cell, $client->id );
        push( @cell, $client->name );
        push( @cell, $client->location );
        push( @cell, defined( $client->session ) ? $client->session->status : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->id : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->username : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->password : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->minutes : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->status : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->message : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->notes : undef );
        push( @cell, defined( $client->session ) ? $client->session->user->is_troublemaker : undef );

        my $single_row = {
            cell => \@cell
        };
        push( @row_data, $single_row );
    }
    
    $self->status_ok(
        $c,
        entity => {
            page => $c->stash->{json_data}->{page},
            total => $c->stash->{json_data}->{total},
            records => $c->stash->{json_data}->{records},
            rows => \@row_data
        }
    );
}

sub clients_POST {
    my ( $self, $c ) = @_;
    
    my $params = $c->request->params;
    my $clients_rs = $c->model('DB::User');

    
    my $op = $params->{'oper'};
    $c->log->debug("Operation is '$op'");

    if ( $op eq 'add' ) {
        $c->log->debug('Adding new user');
        ## Create new user

        my $fields;
        $fields->{'username'} = $params->{'username'} if ( defined $params->{'username'} );
        $fields->{'password'} = $params->{'password'} if ( defined $params->{'password'} );
        $fields->{'minutes'} = $params->{'minutes'} if ( defined $params->{'minutes'} );
        $fields->{'status'} = $params->{'status'} if ( defined $params->{'status'} );
        $fields->{'message'} = $params->{'message'} if ( defined $params->{'message'} );
        $fields->{'notes'} = $params->{'notes'} if ( defined $params->{'notes'} );
        $fields->{'is_troublemaker'} = ( $params->{'is_troublemaker'} eq 'on' ) ? 'Yes' : 'No' if ( defined $params->{'is_troublemaker'} );

        my $new_user = $clients_rs->create( $fields );
        
        $self->status_ok(
            $c,
            entity => {
            }
        );

    } elsif ( $op eq 'edit' ) { 
        $c->log->debug('Edit existing user');
        ## Edit existing user
        my $client_id = $params->{'id'};

        my $client = $clients_rs->find( { id => $client_id } );

        my $fields;
        $fields->{'username'} = $params->{'username'} if ( defined $params->{'username'} );
        $fields->{'password'} = $params->{'password'} if ( defined $params->{'password'} );
        $fields->{'minutes'} = $params->{'minutes'} if ( defined $params->{'minutes'} );
        $fields->{'status'} = $params->{'status'} if ( defined $params->{'status'} );
        $fields->{'message'} = $params->{'message'} if ( defined $params->{'message'} );
        $fields->{'notes'} = $params->{'notes'} if ( defined $params->{'notes'} );
        $fields->{'is_troublemaker'} = $params->{'is_troublemaker'} if ( defined $params->{'is_troublemaker'} );
    
        $client->update( $fields );

        $self->status_ok(
            $c,
            entity => {
            }
        );
    } elsif ( $op eq 'del' ) {
        $c->log->debug('Deleting existing user');
        ## Delete existing user
        my $client_id = $params->{'id'};
        $clients_rs->find( { id => $client_id } )->delete();
        
        $self->status_ok(
            $c,
            entity => {
            }
        );
        
    } else {
        ## No operation given
        $c->log->debug('No operation given');
    }

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
