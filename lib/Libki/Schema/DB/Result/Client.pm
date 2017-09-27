use utf8;
package Libki::Schema::DB::Result::Client;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::Client

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::EncodedColumn>

=item * L<DBIx::Class::Numeric>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "TimeStamp",
  "EncodedColumn",
  "Numeric",
);

=head1 TABLE: C<clients>

=cut

__PACKAGE__->table("clients");

=head1 ACCESSORS

=head2 instance

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 location

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 last_registered

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "location",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_registered",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name>

=over 4

=item * L</instance>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["instance", "name"]);

=head1 RELATIONS

=head2 client_age_limits

Type: has_many

Related object: L<Libki::Schema::DB::Result::ClientAgeLimit>

=cut

__PACKAGE__->has_many(
  "client_age_limits",
  "Libki::Schema::DB::Result::ClientAgeLimit",
  { "foreign.client" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 reservation

Type: might_have

Related object: L<Libki::Schema::DB::Result::Reservation>

=cut

__PACKAGE__->might_have(
  "reservation",
  "Libki::Schema::DB::Result::Reservation",
  { "foreign.client_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 session

Type: might_have

Related object: L<Libki::Schema::DB::Result::Session>

=cut

__PACKAGE__->might_have(
  "session",
  "Libki::Schema::DB::Result::Session",
  { "foreign.client_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-03 10:50:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yMsPvwZxYzjpzGVvRqb22A

=head2 can_user_use

$client->can_user_use( { user => $user, error => $error, c => $c } )

Given a user, this method returns true if the user is allowed to use the
given client.

If hashref $error is passed in, the specific error message will be set in $error.

=cut

sub can_user_use {
    my ( $self, $params ) = @_;

    my $user  = $params->{user};
    my $error = $params->{error};
    my $c     = $params->{c};

    my $log = $c->log();
    $log->debug("Client::can_user_user( $self, { user => $user, error => $error, c => $c }");

    unless ( $user ) {
        $error->{reason}  = 'NO_USER';
        return 0;
    }

    if ( my @age_limits = $self->client_age_limits() ) {
        my $age = $user->age();
	$log->debug("User age: $age");

        foreach my $age_limit ( @age_limits ) {
            my $comparison = $age_limit->comparison();
            my $limit = $age_limit->age();
            $log->debug("Age comparison: $comparison");
            $log->debug("Age limit: $limit");

            my $bool;
            if ( $comparison eq 'eq' ) {
                $bool = $age == $limit;
            } elsif ( $comparison eq 'ne' ) {
                $bool = $age != $limit;
            } elsif ( $comparison eq 'gt' ) {
                $bool = $age > $limit;
            } elsif ( $comparison eq 'lt' ) {
                $bool = $age > $limit;
            } elsif ( $comparison eq 'ge' ) {
                $bool = $age >= $limit;
            } elsif ( $comparison eq 'le' ) {
                $bool = $age <= $limit;
            }

            $log->debug("$age $comparison $limit = $bool");
            unless ( $bool ) {
                $error->{reason}     = 'AGE_MISMATCH';
                $error->{comparison} = $comparison;
                $error->{limit}      = $limit;
                $error->{age}        = $age;
                return 0;
            }
        }
    } 

    $error->{success} = 1;
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

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
