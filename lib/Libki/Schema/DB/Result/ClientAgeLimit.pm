use utf8;
package Libki::Schema::DB::Result::ClientAgeLimit;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::ClientAgeLimit

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

=head1 TABLE: C<client_age_limits>

=cut

__PACKAGE__->table("client_age_limits");

=head1 ACCESSORS

=head2 instance

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 client

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 comparison

  data_type: 'enum'
  extra: {list => ["eq","ne","gt","lt","le","ge"]}
  is_nullable: 0

=head2 age

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "client",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "comparison",
  {
    data_type => "enum",
    extra => { list => ["eq", "ne", "gt", "lt", "le", "ge"] },
    is_nullable => 0,
  },
  "age",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_age_limits>

=over 4

=item * L</instance>

=item * L</client>

=item * L</comparison>

=item * L</age>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "unique_age_limits",
  ["instance", "client", "comparison", "age"],
);

=head1 RELATIONS

=head2 client

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::Client>

=cut

__PACKAGE__->belongs_to(
  "client",
  "Libki::Schema::DB::Result::Client",
  { id => "client" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-03 10:50:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9Gu0cOQ6wQNGXNEKLq43Pg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
