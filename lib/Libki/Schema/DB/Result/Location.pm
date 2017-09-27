use utf8;
package Libki::Schema::DB::Result::Location;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::Location

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

=head1 TABLE: C<locations>

=cut

__PACKAGE__->table("locations");

=head1 ACCESSORS

=head2 instance

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_code>

=over 4

=item * L</instance>

=item * L</code>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_code", ["instance", "code"]);

=head1 RELATIONS

=head2 closing_hours

Type: has_many

Related object: L<Libki::Schema::DB::Result::ClosingHour>

=cut

__PACKAGE__->has_many(
  "closing_hours",
  "Libki::Schema::DB::Result::ClosingHour",
  { "foreign.location" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-03 10:50:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vgl9lHQhYtVyJ5OlTk6Zxg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
