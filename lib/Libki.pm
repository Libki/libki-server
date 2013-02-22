package Libki;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

use DateTime;
use DateTime::Format::DateParse;
use DateTime::Format::MySQL;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
  -Debug
  ConfigLoader
  Static::Simple

  StackTrace

  Authentication
  Authorization::Roles

  Session
  Session::Store::File
  Session::State::Cookie

  StatusMessage
  
  Breadcrumbs
  /;

extends 'Catalyst';

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in libki.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'Libki',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header                      => 1,   # Send X-Catalyst header
);

__PACKAGE__->config(
    'View::HTML' => {
        INCLUDE_PATH => [
            __PACKAGE__->path_to( 'root', 'dynamic', 'templates' ),
            __PACKAGE__->path_to( 'root', 'dynamic', 'includes' ),
        ],

        PLUGIN_BASE => 'Libki::Template::Plugin',
        
        # Set to 1 for detailed timer stats in your HTML as comments
        TIMER   => 0,
        WRAPPER => 'wrapper.tt',
    },
    'default_view' => 'HTML',
);

__PACKAGE__->config(
    breadcrumbs => {
        hide_index => 1,
        hide_home  => 1,
    },
);


# Start the application
__PACKAGE__->setup();

=head1 NAME

Libki - Catalyst based application

=head1 SYNOPSIS

    script/libki_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Libki::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Kyle M. Hall <kyle@kylehall.info>

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

1;
