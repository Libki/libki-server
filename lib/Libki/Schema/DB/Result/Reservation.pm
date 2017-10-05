use utf8;
package Libki::Schema::DB::Result::Reservation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::Reservation

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

=head1 TABLE: C<reservations>

=cut

__PACKAGE__->table("reservations");

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

=head2 client_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 expiration

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "client_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "expiration",
  {
    data_type => "datetime",
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

=head2 C<client_id>

=over 4

=item * L</client_id>

=back

=cut

__PACKAGE__->add_unique_constraint("client_id", ["client_id"]);

=head2 C<user_id>

=over 4

=item * L</user_id>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id", ["user_id"]);

=head1 RELATIONS

=head2 client

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::Client>

=cut

__PACKAGE__->belongs_to(
  "client",
  "Libki::Schema::DB::Result::Client",
  { id => "client_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 user

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Libki::Schema::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-05 09:11:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AlFVGhFUuTyggrbjQ0GmvQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
