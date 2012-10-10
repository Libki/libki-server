package Libki::Controller::Administration::API::DataTables;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Libki::Controller::Administration::API::DataTables - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub users : Local Args(0) {
    my ( $self, $c ) = @_;

    # We need to map the table columns to field names for ordering
    my @columns =
      qw/me.username me.minutes me.status me.message me.notes me.is_troublemaker client.name session.status/;

    my $search_term = $c->request->param("sSearch");
    my $filter;
    if ($search_term) {
        $filter = {
            -or => [
                'me.username' => { 'like', "%$search_term%" },
                'me.notes'    => { 'like', "%$search_term%" },
                'me.message'  => { 'like', "%$search_term%" },
            ]
        };
    }

    # Sorting options
    my @sorting;
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-'
                  . $c->request->param("sSortDir_$i") =>
                  $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
    }

  # May need editing with a filter if the table contains records for other items
  # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
  # in this case, we'd only want the count of notes affecting the specific item,
  # not *all* items
    my $total_records = $c->model('DB::User')->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::User')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @users = $c->model('DB::User')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('iDisplayLength'),
            offset   => $c->request->param('iDisplayStart'),
            prefetch => { session => 'client' },
        }
    );

    my @results;
    foreach my $u (@users) {
        my $r;
        $r->{'DT_RowId'} = $u->id;
        $r->{'0'}        = $u->username;
        $r->{'1'}        = $u->minutes;
        $r->{'2'}        = $u->status;
        $r->{'3'}        = $u->message;
        $r->{'4'}        = $u->notes;
        $r->{'5'}        = $u->is_troublemaker;
        $r->{'6'} = defined( $u->session ) ? $u->session->client->name : undef;
        $r->{'7'} = defined( $u->session ) ? $u->session->status : undef;

        push( @results, $r );
    }

    $c->stash(
        {
            'iTotalRecords'        => $total_records,
            'iTotalDisplayRecords' => $count,
            'sEcho'                => $c->request->param('sEcho') || undef,
            'aaData'               => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

sub clients : Local Args(0) {
    my ( $self, $c ) = @_;

    # We need to map the table columns to field names for ordering
    my @columns =
      qw/ me.name session.status user.username user.minutes user.status user.message user.notes user.is_troublemaker/;

    my $search_term = $c->request->param("sSearch");
    my $filter;
    if ($search_term) {
        $filter = {
            -or => [
                'me.name'       => { 'like', "%$search_term%" },
                'me.location'   => { 'like', "%$search_term%" },
                #'user.username' => { 'like', "%$search_term%" },
                #'user.notes'    => { 'like', "%$search_term%" },
                #'user.message'  => { 'like', "%$search_term%" },
            ]
        };
    }

    # Sorting options
    my @sorting;
    for ( my $i = 0 ; $i < $c->request->param('iSortingCols') ; $i++ ) {
        push(
            @sorting,
            {
                '-'
                  . $c->request->param("sSortDir_$i") =>
                  $columns[ $c->request->param("iSortCol_$i") ]
            }
        );
    }

  # May need editing with a filter if the table contains records for other items
  # not caught by the filter e.g. a "item" table with a FK to a "notes" table -
  # in this case, we'd only want the count of notes affecting the specific item,
  # not *all* items
    my $total_records = $c->model('DB::Client')->count;

    # In case of pagination, we need to know how many records match in total
    my $count = $c->model('DB::Client')->count($filter);

    # Do the search, including any required sorting and pagination.
    my @clients = $c->model('DB::Client')->search(
        $filter,
        {
            order_by => \@sorting,
            rows     => $c->request->param('iDisplayLength'),
            offset   => $c->request->param('iDisplayStart'),
            prefetch => { session => 'user' },
        }
    );

    my @results;
    foreach my $c (@clients) {
        my $r;
        $r->{'DT_RowId'} = $c->id;
        $r->{'0'}        = $c->name;
        $r->{'1'}        = $c->location;
        $r->{'2'}        = defined( $c->session ) ? $c->session->status : undef;
        $r->{'3'} =
    defined( $c->session ) ? $c->session->user->username : undef;
        $r->{'4'} = defined( $c->session ) ? $c->session->user->minutes : undef;
        $r->{'5'} = defined( $c->session ) ? $c->session->user->status  : undef;
        $r->{'6'} = defined( $c->session ) ? $c->session->user->message : undef;
        $r->{'7'} = defined( $c->session ) ? $c->session->user->notes   : undef;
        $r->{'8'} =
          defined( $c->session ) ? $c->session->user->is_troublemaker : undef;

        push( @results, $r );
    }

    $c->stash(
        {
            'iTotalRecords'        => $total_records,
            'iTotalDisplayRecords' => $count,
            'sEcho'                => $c->request->param('sEcho') || undef,
            'aaData'               => \@results,
        }
    );
    $c->forward( $c->view('JSON') );
}

=head1 AUTHOR

libki,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
