package Catalyst::Plugin::LibkiSetting;

use Modern::Perl;

our $VERSION = 1;

=head2 setting

Returns the setting value for a given setting name and Libki instance.
If the setting does not exist in storage, an empty string will be returned.

=cut

sub setting {
    my ( $c, $params ) = @_;

    my ( $instance, $name );

    if ( ref $params eq 'HASH' ) {
        $instance = $params->{instance};
        $name     = $params->{name};
    } else {
        $name = $params;
    }

    $instance ||= $c->instance;

    my $setting = $c->model('DB::Setting')->find( { instance => $instance, name => $name } );

    return $setting ? $setting->value : q{};
}

=head2 instance

Returns the current instance name.
The instance name can be set using the environment variable 'LIBKI_INSTANCE'
or via the http header 'libki-instance'
If neither is set, the instance name will be an empty string.

=cut

sub instance {
    my ($c) = @_;

    my $header = $c->request->headers->{'libki-instance'} || q{};
    my $env = $ENV{LIBKI_INSTANCE} || q{};

    my $instance = $header || $env || q{};

    return $instance;
}

=head2 now

Returns a DataTime::now object corrected for the current timezone.

=cut

sub now {
    return DateTime->now( time_zone => $ENV{TZ} );
}

1;
