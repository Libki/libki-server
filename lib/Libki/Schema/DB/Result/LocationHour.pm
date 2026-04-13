use utf8;
package Libki::Schema::DB::Result::LocationHour;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::LocationHour

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

=head1 TABLE: C<location_hours>

=cut

__PACKAGE__->table("location_hours");

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

=head2 day_of_week

  data_type: 'smallint'
  is_nullable: 0

=head2 open_time

  data_type: 'time'
  is_nullable: 0

=head2 close_time

  data_type: 'time'
  is_nullable: 0

=head2 reservable

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "day_of_week",
  { data_type => "smallint", is_nullable => 0 },
  "open_time",
  { data_type => "time", is_nullable => 0 },
  "close_time",
  { data_type => "time", is_nullable => 0 },
  "reservable",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
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

=item * L</day_of_week>

=item * L</open_time>

=item * L</close_time>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "location_id",
  ["location_id", "day_of_week", "open_time", "close_time"],
);

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


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-13 14:01:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/XujjAij3lI18xEDQYMzEA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
