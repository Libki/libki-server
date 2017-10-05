use utf8;
package Libki::Schema::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::User

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

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 instance

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 32

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 password

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 minutes_allotment

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 minutes

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 status

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 notes

  data_type: 'text'
  is_nullable: 0

=head2 is_troublemaker

  data_type: 'enum'
  default_value: 'No'
  extra: {list => ["Yes","No"]}
  is_nullable: 0

=head2 is_guest

  data_type: 'enum'
  default_value: 'No'
  extra: {list => ["Yes","No"]}
  is_nullable: 0

=head2 birthdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "minutes_allotment",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "minutes",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "notes",
  { data_type => "text", is_nullable => 0 },
  "is_troublemaker",
  {
    data_type => "enum",
    default_value => "No",
    extra => { list => ["Yes", "No"] },
    is_nullable => 0,
  },
  "is_guest",
  {
    data_type => "enum",
    default_value => "No",
    extra => { list => ["Yes", "No"] },
    is_nullable => 0,
  },
  "birthdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_username>

=over 4

=item * L</instance>

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_username", ["instance", "username"]);

=head1 RELATIONS

=head2 messages

Type: has_many

Related object: L<Libki::Schema::DB::Result::Message>

=cut

__PACKAGE__->has_many(
  "messages",
  "Libki::Schema::DB::Result::Message",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 reservation

Type: might_have

Related object: L<Libki::Schema::DB::Result::Reservation>

=cut

__PACKAGE__->might_have(
  "reservation",
  "Libki::Schema::DB::Result::Reservation",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 session

Type: might_have

Related object: L<Libki::Schema::DB::Result::Session>

=cut

__PACKAGE__->might_have(
  "session",
  "Libki::Schema::DB::Result::Session",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_roles

Type: has_many

Related object: L<Libki::Schema::DB::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "Libki::Schema::DB::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-05 09:11:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Dd9QeIGJ+b7aVDWhmTjrCQ

__PACKAGE__->numeric_columns(qw/minutes minutes_allotment/);

__PACKAGE__->add_columns(
    'password' => {
        data_type           => "TEXT",
        size                => undef,
        encode_column       => 1,
        encode_class        => 'Digest',
        encode_args         => {
          algorithm   => 'MD5',
          format      => 'base64',   
          salt_length => 0
        },
        encode_check_method => 'check_password',
    },
);

=head2 has_role
    
Check if a user has the specified role
            
=cut

use Perl6::Junction qw/any/;
sub has_role {
    my ($self, $role) = @_;

    # Does this user posses the required role?
    return any(map { $_->role } $self->roles) eq $role;
}

=head2 insert

Wrap DBIx::Class::Row::insert to handle daily vs session minutes

=cut
sub insert {
    my ( $self, @args ) = @_;

    my $schema = $self->result_source->schema;

    my $default_time_allowance_setting =
      $schema->resultset('Setting')->find({ instance => $self->instance, name => 'DefaultTimeAllowance' });
    my $default_time_allowance = $default_time_allowance_setting ? $default_time_allowance_setting->value : 0;

    my $default_session_time_allowance_setting =
      $schema->resultset('Setting')->find({ instance => $self->instance, name => 'DefaultSessionTimeAllowance' });
    my $default_session_time_allowance = $default_session_time_allowance_setting ? $default_session_time_allowance_setting->value : 0;

    $self->minutes(0) unless $self->minutes();

    while ($self->minutes() < $default_session_time_allowance
        && $self->minutes_allotment() > 0 )
    {
        $self->decrease_minutes_allotment(1);
        $self->increase_minutes(1);
    }

    $self->next::method(@args);

    return $self;
}

sub age {
    my ( $self ) = @_;

    my $birthdate = $self->birthdate();

    return unless $birthdate;

    ($birthdate) = split( /T/, $birthdate );
    my ( $year, $month, $day ) = split( /-/, $birthdate );

    $birthdate = DateTime->new(
        year   => $year,
        month => $month,
        day   => $day,
    );

    my $duration = DateTime->now() - $birthdate;

    my $age = $duration->in_units('years');

    return $age;
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
