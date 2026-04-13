package Libki::Controller::API::V2::Locations;

use Moose;
use namespace::autoclean;
use DateTime;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default => 'application/json',
);

sub locations : Path('/api/v2/locations') : Args(0) : ActionClass('REST') {}
sub location  : Path('/api/v2/locations') : Args(1) : ActionClass('REST') {}
sub hours     : Path('/api/v2/locations') : Args(2) : ActionClass('REST') {}

# GET /api/v2/locations
sub locations_GET {
    my ( $self, $c ) = @_;

    my @locations = $c->model('DB::Location')->search(
        {},
        {
            prefetch => [
                'location_hours',
                { location_hours_exceptions => 'location_hours_exception_intervals' }
            ]
        }
    );
    my @data = map { _serialize_location($c, $_) } @locations;

    $self->status_ok($c, entity => \@data);
}

# POST /api/v2/locations
sub locations_POST {
    my ( $self, $c ) = @_;

    my $params = $c->req->data;

    my $location_values = {
        code      => $params->{code},
        instance  => $c->instance
    };
    if ($params->{parent_id}) {
       $location_values->{parent_id} = $params->{parent_id},
    }

    my $location = $c->model('DB::Location')->create($location_values);

    $self->status_created(
        $c,
        location => $c->req->uri . '/' . $location->id,
        entity   => _serialize_location($c, $location),
    );
}

# GET /api/v2/locations/:id
sub location_GET {
    my ( $self, $c, $id ) = @_;

    my $location = $c->model('DB::Location')->find($id)
        or return $self->status_not_found($c, message => 'Location not found');

    $self->status_ok($c, entity => _serialize_location($c, $location));
}

# PUT /api/v2/locations/:id
sub location_PUT {
    my ( $self, $c, $id ) = @_;

    my $location = $c->model('DB::Location')->find($id)
        or return $self->status_not_found($c, message => 'Location not found');

    my $params = $c->req->data;

    die "Invalid parent_id" if defined $params->{parent_id} && $params->{parent_id} == $location->id;

    my $location_values = {
        code      => $params->{code}
    };
    if ($params->{parent_id}) {
        $location_values->{parent_id} = $params->{parent_id}
    };

    $location->update($location_values);

    $self->status_ok($c, entity => _serialize_location($c, $location));
}

# DELETE /api/v2/locations/:id
sub location_DELETE {
    my ( $self, $c, $id ) = @_;

    my $location = $c->model('DB::Location')->find($id)
        or return $self->status_not_found($c, message => 'Location not found');

    $location->delete;

    $self->status_no_content($c);
}

# GET /api/v2/locations/:id/hours?date=YYYY-MM-DD
sub hours_GET {
    my ( $self, $c, $id ) = @_;

    my $date = $c->req->params->{date}
        or return $self->status_bad_request($c, message => 'Missing date');

    my $location = $c->model('DB::Location')->find($id)
        or return $self->status_not_found($c, message => 'Location not found');

    my $intervals = _resolve_hours($c, $location, $date);

    $self->status_ok($c, entity => {
        location_id => $id,
        date        => $date,
        intervals   => $intervals,
    });
}

# ---- Helper serialization ----

sub _serialize_location {
    my ( $c, $location ) = @_;

    my @hours = map {
        {
            day_of_week => $_->day_of_week,
            open_time   => $_->open_time . '',
            close_time  => $_->close_time . '',
            reservable  => $_->reservable,
        }
    } $location->location_hours;

    my @exceptions = map {
        {
            service_date => $_->service_date . '',
            is_closed    => $_->is_closed ? \1 : \0,
            intervals    => [
                map {
                    {
                        open_time  => $_->open_time . '',
                        close_time => $_->close_time . '',
                        reservable => $_->reservable,
                    }
                } $_->location_hours_exception_intervals
            ],
        }
    } $location->location_hours_exceptions;

    return {
        id        => $location->id,
        code      => $location->code,
        parent_id => $location->parent_id,
        hours     => \@hours,
        exceptions => \@exceptions,
    };
}

sub _resolve_hours {
    my ( $c, $location, $date_str ) = @_;

    my $dt = DateTime->new(
        year  => substr($date_str, 0, 4),
        month => substr($date_str, 5, 2),
        day   => substr($date_str, 8, 2),
    );

    my $dow = ($dt->day_of_week % 7); # 0 = Sunday

    my @chain = _build_location_chain($location);

    # Step 1: exceptions
    foreach my $loc (@chain) {
        my $exception = $c->model('DB::LocationHoursException')->find({
            location_id  => $loc->id,
            service_date => $date_str,
        });

        next unless $exception;

        return [] if $exception->is_closed;

        return [
            map {
                {
                    open_time  => $_->open_time . '',
                    close_time => $_->close_time . '',
                }
            } $exception->location_hours_exception_intervals
        ];
    }

    # Step 2: weekly hours
    foreach my $loc (@chain) {
        my @hours = $c->model('DB::LocationHour')->search({
            location_id => $loc->id,
            day_of_week => $dow,
        });

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

sub _build_location_chain {
    my ($location) = @_;

    my @chain;
    my $current = $location;

    while ($current) {
        push @chain, $current;
        $current = $current->parent;
    }

    return @chain; # child → root
}

__PACKAGE__->meta->make_immutable;

1;
