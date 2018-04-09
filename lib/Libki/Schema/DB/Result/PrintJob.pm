use utf8;
package Libki::Schema::DB::Result::PrintJob;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::PrintJob

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

=head1 TABLE: C<print_jobs>

=cut

__PACKAGE__->table("print_jobs");

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

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 status

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 data

  data_type: 'text'
  is_nullable: 1

=head2 printer

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 print_file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 created_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: 'CURRENT_TIMESTAMP'
  is_nullable: 0

=head2 updated_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: 'CURRENT_TIMESTAMP'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "data",
  { data_type => "text", is_nullable => 1 },
  "printer",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "print_file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "created_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "CURRENT_TIMESTAMP",
    is_nullable => 0,
  },
  "updated_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "CURRENT_TIMESTAMP",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 print_file

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::PrintFile>

=cut

__PACKAGE__->belongs_to(
  "print_file",
  "Libki::Schema::DB::Result::PrintFile",
  { id => "print_file_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 user

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Libki::Schema::DB::Result::User",
  { id => "user_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-12-12 08:29:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:m9fd/i3yrU521Ikq2OdpJQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
