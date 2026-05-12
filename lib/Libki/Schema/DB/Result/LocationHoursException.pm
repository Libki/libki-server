use utf8;
package Libki::Schema::DB::Result::LocationHoursException;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::LocationHoursException

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

=head1 TABLE: C<location_hours_exceptions>

=cut

__PACKAGE__->table("location_hours_exceptions");

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

=head2 location_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 service_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 is_closed

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "service_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "is_closed",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<location_id>

=over 4

=item * L</location_id>

=item * L</service_date>

=back

=cut

__PACKAGE__->add_unique_constraint("location_id", ["location_id", "service_date"]);

=head1 RELATIONS

=head2 location

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::Location>

=cut

__PACKAGE__->belongs_to(
  "location",
  "Libki::Schema::DB::Result::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 location_hours_exception_intervals

Type: has_many

Related object: L<Libki::Schema::DB::Result::LocationHoursExceptionInterval>

=cut

__PACKAGE__->has_many(
  "location_hours_exception_intervals",
  "Libki::Schema::DB::Result::LocationHoursExceptionInterval",
  { "foreign.exception_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-03-25 16:44:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0bVwBpby6CUtLrAUQlKj4g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
