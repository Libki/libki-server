package Libki::Clients;

use Modern::Perl;
use IO::Socket::INET;

=head2 wakeonlan

Send a magic packet for every MAC address in the ClientMACAddresses setting.

=cut

sub wakeonlan {
    my ($c) = @_;

    my $success = 1;

    my $host = $c->setting('WOLHost') || '255.255.255.255';
    my $port = $c->setting('WOLPort') || 9;
    my $sockaddr = sockaddr_in($port, inet_aton($host));

    my @mac_addresses = get_wol_mac_addresses();

    foreach my $mac_address (@mac_addresses) {
        my $socket = new IO::Socket::INET( Proto => 'udp' )
            or $c->log()->fatal("ERROR in Socket Creation : $!\n");

        if ($socket) {
            $c->log()->debug("Sending magic packet to $mac_address at $host:$port");
            $mac_address =~ s/://g;
            my $packet = pack('C6H*', 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, $mac_address x 16);

            setsockopt($socket, SOL_SOCKET, SO_BROADCAST, 1);
            $success = 0 unless send($socket, $packet, 0, $sockaddr);
            $socket->close;
        } else {
            $success = 0;
        }
    }

    return $success;
}

=head2 get_wol_mac_addresses

Get MAC addresses from clients and add them to MAC address in the ClientMACAddresses setting.

=cut

sub get_wol_mac_addresses {
    
    my ($c) = @_;

    my $mac_addresses_setting = $c->setting('ClientMACAddresses');
    my @mac_addresses_from_setting = split(/[\r\n]+/, $mac_addresses_setting);

    my @clients_with_mac_address = $c->model('DB::client')->search( { macaddress => { '!=', undef } } );

    my @all_mac_addresses = (@mac_addresses_from_setting, @clients_with_mac_address);

    return @all_mac_addresses;
}

=head1 AUTHOR

Maryse Simard <maryse.simard@inlibro.com>

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
