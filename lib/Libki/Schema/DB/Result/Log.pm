use utf8;
package Libki::Schema::DB::Result::Log;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::Log

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

=head1 TABLE: C<logs>

=cut

__PACKAGE__->table("logs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 instance

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 1
  size: 32

=head2 created_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: 'current_timestamp()'
  is_nullable: 0

=head2 pid

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 hostname

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 100

=head2 level

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 message

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 1, size => 32 },
  "created_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "current_timestamp()",
    is_nullable => 0,
  },
  "pid",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "hostname",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 100 },
  "level",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "message",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-01-10 10:09:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ssgTVM26jwMiKXwGTypCMw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
