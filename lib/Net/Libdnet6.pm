#
# $Id: Libdnet6.pm,v 1.4 2006/12/28 09:58:25 gomor Exp $
#
package Net::Libdnet6;
use strict;
use warnings;

our $VERSION = '0.20';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
   addr_cmp6
   addr_bcast6
   addr_net6
   arp_add6
   arp_delete6
   arp_get6
   intf_get6
   intf_get_src6
   intf_get_dst6
   intf_set6
   route_add6
   route_delete6
   route_get6

   addr_cmp
   addr_bcast
   addr_net
   arp_add
   arp_delete
   arp_get
   intf_get
   intf_get_src
   intf_get_dst
   intf_set
   route_add
   route_delete
   route_get
);

BEGIN {
   my $osname = {
      linux   => [ \&_get_routes_linux, ],
      freebsd => [ \&_get_routes_bsd,   ],
      openbsd => [ \&_get_routes_bsd,   ],
      netbsd  => [ \&_get_routes_bsd,   ],
      darwin  => [ \&_get_routes_bsd,   ],
   };

   *_get_routes = $osname->{$^O}->[0] || \&_get_routes_other;
}

use Carp;
use Net::Libdnet;
require Net::IPv6Addr;

sub arp_add6    { croak("Not supported\n") }
sub arp_delete6 { croak("Not supported\n") }
sub arp_get6    { croak("Not supported\n") }

sub intf_set6     { croak("Not supported\n") }
sub intf_get_src6 { croak("Not supported\n") }

sub route_add6    { croak("Not supported\n") }
sub route_delete6 { croak("Not supported\n") }

sub addr_cmp6   { croak("Not supported\n") }
sub addr_bcast6 { croak("Not supported\n") }

sub _to_string_preferred  { Net::IPv6Addr->new(shift())->to_string_preferred  }
sub _to_string_compressed { Net::IPv6Addr->new(shift())->to_string_compressed }

sub addr_net6 {
   my $net = shift;
   # XXX: confess
   my ($ip, $mask) = split('/', $net);
   $ip = _to_string_preferred($ip);
   $mask /= 8; # Convert to number of bytes
   my $subnet;
   my $count = 0;
   for (split(':', $ip)) {
      if ($count < $mask) {
         $subnet .= $_.':';
         $count += 2; # Each element takes two bytes
      }
      else {
         $subnet .= '0:';
      }
   }
   $subnet =~ s/:$//;
   _to_string_compressed($subnet);
}

sub _get_ip6 {
   my $dev = shift;

   # XXX: No IP6 under Windows for now
   return undef if $^O =~ m/MSWin32|cygwin/i;

   my $buf = `/sbin/ifconfig $dev 2> /dev/null`;

   my @ip6 = ();
   if ($buf) {
      for (split('\n', $buf)) {
         my $prefixLenFound;
         my $lastIp6;
         for (split(/\s+/)) {
            s/(?:%[a-z0-9]+)$//; # This removes %lnc0 on BSD systems

            if (Net::IPv6Addr::is_ipv6($_)) {
               $lastIp6 = lc($_);
            }

            # Gather prefixlen on *BSD systems
            if (/^\d+$/ && $prefixLenFound) {
               $lastIp6 .= '/'.$_;
               --$prefixLenFound;
            }
            ++$prefixLenFound if /^prefixlen$/i;
         }
         push @ip6, $lastIp6 if $lastIp6;
      }
   }

   # We return the first IP as the main address, others as aliases
   if (@ip6 > 1) {
      return $ip6[0], [ @ip6[1..$#ip6] ];
   }
   elsif (@ip6 == 1) {
      return $ip6[0];
   }
   undef;
}

sub intf_get6 {
   my $dev = shift;

   # XXX: confess()
   my $dnet = intf_get($dev);
   my ($ip, $aliases) = _get_ip6($dev);
   $dnet->{addr6}    = $ip       if $ip;
   $dnet->{aliases6} = $aliases  if $aliases;

   $dnet;
}

sub _get_routes_other { croak("Not supported\n") }

sub _get_routes_linux {
   my @ifRoutes = ();
   my $buf = `netstat -rnA inet6`;
   my %devIps;
   if ($buf) {
      my @lines = split('\n', $buf);
      for (@lines) {
         my @elts = split(/\s+/);
         if ($elts[0]) {
            if ($elts[0] eq '::/0') { # Default route
               my $route = {
                  destination => 'default',
                  interface   => $elts[-1],
               };
               if (Net::IPv6Addr::is_ipv6($elts[1])) {
                  $route->{nextHop} = $elts[1];
               }
               push @ifRoutes, $route;
            }
            elsif (Net::IPv6Addr::is_ipv6($elts[0])) {
               my $route = {
                  destination => $elts[0],
                  interface   => $elts[-1],
               };
               if (Net::IPv6Addr::is_ipv6($elts[1])) {
                  $route->{nextHop} = $elts[1];
               }
               push @ifRoutes, $route;
            }
         }
      }
   }
   else {
      carp("Unable to get routes\n");
      return [];
   }
   \@ifRoutes;
}

sub _get_routes_bsd {
   my @ifRoutes = ();
   my $buf = `netstat -rnf inet6`;
   my %devIps;
   if ($buf) {
      my @lines = split('\n', $buf);
      for (@lines) {
         my @elts = split(/\s+/);
         if ($elts[0]) {
            $elts[0] =~ s/%[a-z]+[0-9]+//;
            if (Net::IPv6Addr::is_ipv6($elts[0])) {
               my $route = {
                  destination => $elts[0],
                  interface   => $elts[-1],
               };
               if (Net::IPv6Addr::is_ipv6($elts[1])) {
                  $route->{nextHop} = $elts[1];
               }
               push @ifRoutes, $route;
            }
            elsif ($elts[0] eq 'default') {
               my $route = {
                  destination => $elts[0],
                  interface   => $elts[-1],
               };
               if (Net::IPv6Addr::is_ipv6($elts[1])) {
                  $route->{nextHop} = $elts[1];
               }
               push @ifRoutes, $route;
            }
         }
      }
   }
   else {
      carp("Unable to get routes\n");
      return [];
   }
   \@ifRoutes;
}

sub _is_in_network {
   my ($src, $net, $mask) = @_;
   my $net1 = addr_net6($src.'/'.$mask);
   my $net2 = addr_net6($net.'/'.$mask);
   $net1 eq $net2;
}

sub intf_get_dst6 {
   my $dst = shift;
   # XXX: confess()
   $dst = _to_string_preferred($dst);

   my $routes = _get_routes();

   # Search network device list for target6
   my @devList = ();
   for my $r (@$routes) {
      my ($net, $mask) = split('/', $r->{destination});

      # If the route is unicast, stop here
      unless ($mask) {
         if ($dst eq $r->{destination}) {
            push @devList, $r->{interface};
            last;
         }
      }
      else {
         $net = _to_string_preferred($net);
         if (_is_in_network($dst, $net, $mask)) {
            push @devList, $r->{interface};
         }
      }
   }

   my @devs;
   if (@devList > 0) {
      @devs = map { intf_get6($_) } @devList;
   }
   else {
      # Not on same network, should use default gw
      for my $r (@$routes) {
         if ($r->{destination} eq 'default') {
            push @devs, intf_get6($r->{interface});
         }
      }
   }

   # Now, search the correct source IP, if multiple found
   for (@devs) {
      if (exists $_->{addr6} && exists $_->{aliases6}) {
         my @ipList = ( $_->{addr6}, @{$_->{aliases6}} );
         for my $i (@ipList) {
            my ($net, $mask) = split('/', $i);

            if (_is_in_network($dst, $net, $mask)) {
               my @ipNotMain = grep {!/^$i$/} @ipList;
               $_->{addr6}    = $i;
               $_->{aliases6} = \@ipNotMain;
            }
         }
      }
   }

   wantarray ? @devs : $devs[0];
}

sub _search_next_hop {
   my $dev = shift;
   my ($dst, $hops) = @_;
   for my $h (@$hops) {
      my ($net, $mask) = split('/', $dev->{addr6});
      if (! _is_in_network($dst, $net, $mask)) {
         for my $i ($dev->{addr6}, @{$dev->{aliases6}}) {
            my ($iNet, $iMask) = split('/', $i);
            if (_is_in_network($h, $iNet, $iMask)) {
               return $h;
            }
         }
      }
   }
   undef;
}

sub route_get6 {
   my $dst = shift;
   # XXX: confess
   $dst = _to_string_preferred($dst);

   my @devs = intf_get_dst6($dst);
   return undef unless @devs > 0;

   my @nextHops = ();
   for my $r (@{_get_routes()}) {
      push @nextHops, $r->{nextHop} if $r->{nextHop};
   }

   my $nextHop;
   for my $d (@devs) {
      $nextHop = _search_next_hop($d, $dst, \@nextHops);
   }

   $nextHop;
}

1;

__END__

=head1 NAME

Net::Libdnet6 - adds IPv6 support to Net::Libdnet

=head1 DESCRIPTION

=head1 SUBROUTINES

=over 4

=item B<addr_bcast6>

=item B<addr_cmp6>

=item B<addr_net6>

=item B<arp_add6>

=item B<arp_delete6>

=item B<arp_get6>

=item B<intf_get6>

=item B<intf_get_dst6>

=item B<intf_get_src6>

=item B<intf_set6>

=item B<route_add6>

=item B<route_delete6>

=item B<route_get6>

=back

=head1 SEE ALSO

L<Net::Libdnet>

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of the Artistic license.
See LICENSE.Artistic file in the source distribution archive.

=cut
