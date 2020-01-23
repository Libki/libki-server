use utf8;
package Libki::Schema::DB::Result::Statistic;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Libki::Schema::DB::Result::Statistic

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

=head1 TABLE: C<statistics>

=cut

__PACKAGE__->table("statistics");

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

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 client_name

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 client_location

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 client_type

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 action

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 created_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 anonymized

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 session_id

  data_type: 'char'
  is_nullable: 1
  size: 72

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "client_name",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "client_location",
  { data_type => "varchar", is_nullable => 1, size => 191 },
  "client_type",
  { data_type => "varchar", is_nullable => 1, size => 191 },
  "action",
  { data_type => "varchar", is_nullable => 1, size => 191 },
  "created_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "anonymized",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "session_id",
  { data_type => "char", is_nullable => 1, size => 72 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-11-01 12:22:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qtwYDmDIG9LqQJXnv1znpQ


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
