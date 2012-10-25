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

=head2 message

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

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "minutes",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "notes",
  { data_type => "text", is_nullable => 0 },
  "message",
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
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<username>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("username", ["username"]);

=head1 RELATIONS

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


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2012-10-25 15:15:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rn+bsxM4gz9un/HWYEWnBw

__PACKAGE__->numeric_columns(qw/minutes/);

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

__PACKAGE__->meta->make_immutable;
1;
