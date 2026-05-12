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
            order_by => 'code',
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
    my $schema = $c->model('DB')->schema;
    my $location;

    $schema->txn_do(sub {
        $location = $c->model('DB::Location')->create({
            code      => $params->{code},
            parent_id => $params->{parent_id},
            instance  => $c->instance
        });

        _replace_related( $location, $params );
    });

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
    my $schema = $c->model('DB')->schema;

    die "Invalid parent_id" if defined $params->{parent_id} && $params->{parent_id} == $location->id;

    $schema->txn_do(sub {

        $location->update({
            code      => $params->{code},
            parent_id => $params->{parent_id},
        });

        _replace_related( $location, $params );
    });

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

    my $intervals = $location->hours_for_date($date);

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
            service_date => $c->format_dt( { dt => $_->service_date, format => '%Y-%m-%d' } ),
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
        id              => $location->id,
        code            => $location->code,
        parent_id       => $location->parent_id,
        hours           => \@hours,
        effective_hours => $location->effective_hours,
        exceptions      => \@exceptions,
    };
}

sub _replace_related {
    my ( $location, $params ) = @_;

    # delete existing weekly hours
    $location->location_hours->delete;

    # delete existing exceptions (cascade should remove intervals)
    $location->location_hours_exceptions->delete;

    # recreate weekly hours
    foreach my $h ( @{ $params->{hours} || [] } ) {

        $location->location_hours->create({
            day_of_week => $h->{day_of_week},
            open_time   => $h->{open_time},
            close_time  => $h->{close_time},
            reservable  => $h->{reservable},
        });
    }

    # recreate exceptions
    foreach my $e ( @{ $params->{exceptions} || [] } ) {

        my $exception = $location->location_hours_exceptions->create({
            service_date => $e->{service_date},
            is_closed    => $e->{is_closed} ? 1 : 0,
        });

        foreach my $i ( @{ $e->{intervals} || [] } ) {

            $exception->location_hours_exception_intervals->create({
                open_time  => $i->{open_time},
                close_time => $i->{close_time},
                reservable => $i->{reservable},
            });
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;
