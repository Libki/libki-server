use utf8;
package Libki::Schema::DB::Result::ClosingHour;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::ClosingHour

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

=head1 TABLE: C<closing_hours>

=cut

__PACKAGE__->table("closing_hours");

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

=head2 location

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 day

  data_type: 'enum'
  extra: {list => ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]}
  is_nullable: 1

=head2 date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 closing_time

  data_type: 'time'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "location",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "day",
  {
    data_type => "enum",
    extra => {
      list => [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
      ],
    },
    is_nullable => 1,
  },
  "date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "closing_time",
  { data_type => "time", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 location

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::Location>

=cut

__PACKAGE__->belongs_to(
  "location",
  "Libki::Schema::DB::Result::Location",
  { id => "location" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-05 09:11:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:S2EeBdJB53Qe01wGCSQ6bQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
