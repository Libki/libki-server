package Libki::Users;

use Modern::Perl;

use Text::CSV;

=head2 import_users

Imports users from CSV file.

=cut

sub import_users {
    my ($params)        = @_;
    my $c               = $params->{context};
    my $file            = $params->{file};
    my $delimeter       = $params->{delimeter};
    my $start           = $params->{start};
    my $username_column = $params->{username_column};
    my $password_column = $params->{password_column};
    my $update          = $params->{update};
    my $verbose         = $params->{verbose};
    my $test            = $params->{test};

    my $sep =
        $delimeter eq 'comma' ? ","
      : $delimeter eq 'tab'   ? "\t"
      :                         ",";

    my $csv = Text::CSV->new(
        {
            binary => 1,
            sep    => $sep,
        }
    ) or die "Cannot use CSV: " . Text::CSV->error_diag();

    open my $fh, "<", $file or die "CANNOT OPEN FILE: $!";

    $csv->getline($fh) for 1 .. $start - 1;

    my @unparsable;
    my @updated;
    my @created;
    my @skipped;
    my $i = 0;
    while ( my $line = <$fh> ) {
        $i++;

        if ( $csv->parse($line) ) {

            my @fields   = $csv->fields();
            my $username = $fields[ $params->{username_column} ];
            my $password = $fields[ $params->{password_column} ];

            say "Creating user $username with password $password"
              if $verbose;

            my $r = create_user(
                {
                    context  => $c,
                    username => $username,
                    password => $password,
                    update   => $update,
                }
            ) unless $test;

            if ( $r->{created} ) {
                say "User $username created" if $verbose > 1;
                push( @created, $r );
            }
            elsif ( $r->{exists} && $r->{updated} ) {
                say "User $username already exists, updating"
                  if $verbose > 1;
                push( @updated, $r );
            }
            elsif ( $r->{exists} && !$r->{updated} ) {
                say "User $username already exists, skipping."
                  if $verbose > 1;
                push( @skipped, $r );
            }
        }
        else {
            say "FAILURE TO PARSE LINE: $line";
            push( @unparsable, { number => $i, line => $line } );
        }
    }
    $csv->eof or $csv->error_diag();
    close $fh;

    return {
        created    => \@created,
        updated    => \@updated,
        skipped    => \@skipped,
        unparsable => \@unparsable,
    };
}

=head2 create_user

Creates a user with given paramters, uses defaults for
paramters not passed in.

=cut

sub create_user {
    my ($params) = @_;

    my $c          = $params->{context};
    my $update     = $params->{update};
    my $username   = $params->{username};
    my $password   = $params->{password};
    my $minutes    = $params->{minutes};
    my $admin      = $params->{admin};
    my $superadmin = $params->{superadmin};
    my $instance   = $params->{instance} || $c->instance;

    my $r = {
        exists  => 0,
        created => 0,
        updated => 0,
    };

    my $user_rs = $c->model('DB::User');

    my $user = $user_rs->single(
        {
            instance => $c->instance,
            username => $username,
        }
    );

    if ($user) {
        $r->{exists} = 1;
        if ($update) {
            $r->{updated} = 1;

            $user->set_column( 'password', $password );
            $user->update();
        }
    }
    else {
        $r->{created} = 1;
        my $default_time_allowance = $c->setting('DefaultTimeAllowance') || 0;

        $user = $user_rs->create(
            {
                instance          => $instance,
                username          => $username,
                password          => $password,
                minutes_allotment => $minutes || $default_time_allowance,
                status            => 'enabled',
                is_troublemaker   => 'No',
            }
        );
    }

    if ( $admin || $superadmin ) {
        my $role =
          $c->model('DB::Role')->search( { role => 'admin' } )->single();

        $c->model('DB::UserRole')->update_or_create(
            {
                role_id => $role->id,
                user_id => $user->id,
            }
        );
    }

    if ($superadmin) {
        my $role =
          $c->model('DB::Role')->search( { role => 'superadmin' } )->single();

        $c->model('DB::UserRole')->update_or_create(
            {
                role_id => $role->id,
                user_id => $user->id,
            }
        );
    }

    $r->{user} = $user;
    return $r;
}

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info> 

=cut

=head1 LICENSE
This file is part of Libki.

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

1;
