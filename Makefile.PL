#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'Libki';
all_from 'lib/Libki.pm';

requires 'Catalyst::Runtime' => '5.90011';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Action::RenderView';

requires 'Catalyst::Controller::REST';

requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Authorization::Roles';

requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::File';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::StatusMessage';

requires 'Catalyst::Plugin::Breadcrumbs';
requires 'Catalyst::Plugin::StatusMessage';

requires 'Catalyst::Helper::View::JSON';

requires 'DBIx::Class::TimeStamp';
requires 'DBIx::Class::EncodedColumn';
requires 'DBIx::Class::Numeric';

requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General';

requires 'Perl6::Junction';

requires 'IO::Socket::INET';
requires 'String::Random';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
