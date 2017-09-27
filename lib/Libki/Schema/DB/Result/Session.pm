use utf8;
package Libki::Schema::DB::Result::Session;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::Session

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

=head1 TABLE: C<sessions>

=cut

__PACKAGE__->table("sessions");

=head1 ACCESSORS

=head2 instance

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 client_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 status

  data_type: 'enum'
  default_value: 'active'
  extra: {list => ["active","locked"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "client_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status",
  {
    data_type => "enum",
    default_value => "active",
    extra => { list => ["active", "locked"] },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</client_id>

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("client_id", "user_id");

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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 user

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Libki::Schema::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-03 10:50:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Hd8f9F0qfsZNWxWtYOKObA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
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
