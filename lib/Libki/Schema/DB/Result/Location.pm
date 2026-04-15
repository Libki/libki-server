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
  default_value: (empty string)
  is_nullable: 0
  size: 32

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 parent_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=cut

__PACKAGE__->add_columns(
  "instance",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "parent_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 191 },
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

=head2 location_hours

Type: has_many

Related object: L<Libki::Schema::DB::Result::LocationHour>

=cut

__PACKAGE__->has_many(
  "location_hours",
  "Libki::Schema::DB::Result::LocationHour",
  { "foreign.location_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 location_hours_exceptions

Type: has_many

Related object: L<Libki::Schema::DB::Result::LocationHoursException>

=cut

__PACKAGE__->has_many(
  "location_hours_exceptions",
  "Libki::Schema::DB::Result::LocationHoursException",
  { "foreign.location_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 locations

Type: has_many

Related object: L<Libki::Schema::DB::Result::Location>

=cut

__PACKAGE__->has_many(
  "locations",
  "Libki::Schema::DB::Result::Location",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent

Type: belongs_to

Related object: L<Libki::Schema::DB::Result::Location>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "Libki::Schema::DB::Result::Location",
  { id => "parent_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-03-23 19:39:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QMeIx7YGzeRF0HNC8Gfffg

=head2 ancestors

Return an array of ancestor locations for this location (starting with self)

=cut

sub ancestors {
    my ( $self ) = @_;

    my @chain;
    my $current = $self;

    while ($current) {
        push @chain, $current;
        $current = $current->parent;
    }

    return @chain; # child → root
}


=head2 hours_for_date

Returns the hours intervals for this location on the given date; first
checks exceptions for self then ancestors, then regular hours for self
then ancestors.  Intervals are returned sorted by close_time.

=cut

sub hours_for_date {
    my ( $self, $date_str ) = @_;

    my $schema = $self->result_source->schema;

    my $dt = DateTime->now( time_zone => $ENV{LIBKI_TZ} );
    if ( $date_str ) {
        $dt = DateTime->new(
            year  => substr($date_str, 0, 4),
            month => substr($date_str, 5, 2),
            day   => substr($date_str, 8, 2),
        );
    }

    my $dow = ($dt->day_of_week % 7);
    my @chain = $self->ancestors();

    # Step 1: exceptions
    foreach my $loc (@chain) {
        my $exception = $schema->resultset('LocationHoursException')->find({
            location_id  => $loc->id,
            service_date => $dt->ymd,
        });

        next unless $exception;

        return [] if $exception->is_closed;

        my @rows = $exception->location_hours_exception_intervals->search(
            {},
            { order_by => { -asc => 'close_time' } }
        )->all;
        return [
            map {
                {
                    open_time  => $_->open_time . '',
                    close_time => $_->close_time . '',
                }
            } @rows
        ];
    }

    # Step 2: weekly hours
    foreach my $loc (@chain) {
        my @hours = $schema->resultset('LocationHour')->search(
            {
                location_id => $loc->id,
                day_of_week => $dow,
            },
            {
                order_by => { -asc => 'close_time' },
            }
        )->all;

        return [
            map {
                {
                    open_time  => $_->open_time . '',
                    close_time => $_->close_time . '',
                }
            } @hours
        ] if @hours;
    }

    return [];
}

=head2 minutes_until_closed

Returns the number of minutes until the given Location is closed (or
0 if already closed).  Can be used as a Boolean check for "is open".

=cut

sub minutes_until_closed {
    my ( $self, $dt ) = @_;

    $dt = DateTime->now( time_zone => $ENV{LIBKI_TZ} ) unless $dt;
    my $intervals = $self->hours_for_date($dt->ymd);

    my $minutes_until_closed = 0;
    my $last_closed_time = '';

    foreach my $int (@$intervals) {
       my @open_time_parts  = split( ':', $int->{open_time} );
       my @close_time_parts = split( ':', $int->{close_time} );
       my $open_datetime  = $dt->clone()
                               ->set( hour   => $open_time_parts[0],
                                      minute => $open_time_parts[1] );
       my $close_datetime = $dt->clone()
                               ->set( hour   => $close_time_parts[0],
                                      minute => $close_time_parts[1] );
       # is_between is strictly less/greater than, so push open/close datetimes by a nanosecond to get inclusion
       $open_datetime->subtract(nanoseconds => 1);
       $close_datetime->add(nanoseconds => 1);

       if ( $dt->is_between($open_datetime, $close_datetime) ) {
           my $delta = $close_datetime->subtract_datetime($dt);
           $minutes_until_closed += $delta->in_units('minutes');
           $last_closed_time = $int->{close_time};
       } elsif ($int->{open_time} eq $last_closed_time) {
           my $delta = $close_datetime->subtract_datetime($open_datetime);
           $minutes_until_closed += $delta->in_units('minutes');
           $last_closed_time = $int->{close_time};
       }
    }
warn "Minutes until closed: " . $minutes_until_closed;
    return $minutes_until_closed;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
