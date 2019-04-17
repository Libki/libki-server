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

=head2 instance_config

Locates various parts of the Libki config and returns a unified hashref

=cut

sub instance_config {
    my ($c) = @_;

    my $config = $c->config->{instances}->{ $c->instance } || $c->config;

    unless ( $config->{SIP} ) {
        my $yaml = $c->setting('SIPConfiguration');
        $config->{SIP} = YAML::XS::Load($yaml) if $yaml;
    }

    unless ( $config->{LDAP} ) {
        my $yaml = $c->setting('LDAPConfiguration');
        $config->{LDAP} = YAML::XS::Load($yaml) if $yaml;
    }

    return $config;
}

=head2 now

Returns a DataTime::now object corrected for the current timezone.

=cut

sub now {
    my ($c) = @_;

    return DateTime->now( time_zone => $c->tz );
}

=head2 tz

Returns the current timezone

=cut

sub tz {
    return $ENV{LIBKI_TZ};
}

=head2 user_categories

Returns a list of user categories as defined in the system setting UserCategories

=cut

sub user_categories {
    my ( $c ) = @_;

    my $yaml = $c->setting('UserCategories');

    my $categories = YAML::XS::Load($yaml) if $yaml;

    return $categories;
}


=head2 add_user_category

Returns a list of user categories as defined in the system setting UserCategories

=cut

sub add_user_category {
    my ( $c, $category ) = @_;

    return unless $category;

    my $categories = $c->user_categories;

    return if grep( /^$category$/, @$categories );

    my $setting = $c->model('DB::Setting')->find(
        {
            instance => $c->instance,
            name     => 'UserCategories',
        }
    );

    push( @$categories, $category );

    my $yaml = YAML::XS::Dump( $categories );

    return $setting->update( { value => $yaml } );
}

1;
