#
# $Id: Libdnet6.pm,v 1.1 2006/12/24 13:52:23 gomor Exp $
#
package Net::Libdnet6;
use strict;
use warnings;

our $VERSION = '0.10';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
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
require Net::Libdnet;
require Net::IPv6Addr;

sub arp_add    { croak("Not supported\n") }
sub arp_delete { croak("Not supported\n") }
sub arp_get    { croak("Not supported\n") }

sub intf_set     { croak("Not supported\n") }
sub intf_get_src { croak("Not supported\n") }

sub route_add    { croak("Not supported\n") }
sub route_delete { croak("Not supported\n") }
sub route_get    { croak("TODO\n") }

sub addr_cmp   { croak("Not supported\n") }
sub addr_bcast { croak("Not supported\n") }

sub addr_net {
   my $net = shift;
   # XXX: confess
   my ($ip, $mask) = split('/', $net);
   $ip = Net::IPv6Addr->new($ip)->to_string_preferred;
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
   Net::IPv6Addr->new($subnet)->to_string_compressed;
}

sub _get_ip6 {
   my $dev = shift;

   # XXX: No IP6 under Windows for now
   return undef if $^O =~ m/MSWin32|cygwin/i;

   my $buf = `/sbin/ifconfig $dev 2> /dev/null`;

   my $ip6;
   if ($buf) {
      for (split('\n', $buf)) {
         for (split(/\s+/)) {
            s/(?:%[a-z0-9]+)$//; # This removes %lnc0 on BSD systems
            # XXX: gather prefixlen under *BSD
            $ip6 = $_ if Net::IPv6Addr::is_ipv6($_);
            last if $ip6;
         }
         last if $ip6;
      }
   }

   ($ip6 && lc($ip6)) || undef;
}

sub intf_get {
   my $dev = shift;

   # XXX: confess()
   my $dnet = Net::Libdnet::intf_get($dev);
   $dnet->{addr} = _get_ip6($dev);

   $dnet;
}

sub _get_routes_other { croak("Not supported\n") }

sub _get_routes_linux {
   my %ifRoutes;
   my $buf = `netstat -rnA inet6`;
   my %devIps;
   if ($buf) {
      my @lines = split('\n', $buf);
      for (@lines) {
         my @elts = split(/\s+/);
         if (Net::IPv6Addr::is_ipv6($elts[0])) {
            my $route = {
               destination => $elts[0],
               nextHop     => $elts[1],
               interface   => $elts[-1],
            };
            push @{$ifRoutes{$elts[-1]}}, $route;
         }
      }
   }
   else {
      carp("Unable to get routes\n");
      return undef;
   }
   \%ifRoutes;
}

sub _get_routes_bsd {
   my %ifRoutes;
   my $buf = `netstat -rnf inet6`;
   my %devIps;
   if ($buf) {
      my @lines = split('\n', $buf);
      for (@lines) {
         my @elts = split(/\s+/);
         if (Net::IPv6Addr::is_ipv6($elts[0])) {
            my $route = {
               destination => $elts[0],
               nextHop     => $elts[1],
               interface   => $elts[-1],
            };
            push @{$ifRoutes{$elts[-1]}}, $route;
         }
      }
   }
   else {
      carp("Unable to get routes\n");
      return undef;
   }
   \%ifRoutes;
}

sub _is_in_network {
   my ($src, $net, $mask) = @_;
   my $net1 = Net::Libdnet6::addr_net($src.'/'.$mask);
   my $net2 = Net::Libdnet6::addr_net($net.'/'.$mask);
   $net1 eq $net2;
}

sub intf_get_dst {
   my $dst = shift;
   # XXX: confess()
   $dst = Net::IPv6Addr->new($dst)->to_string_preferred;

   my $routes = _get_routes();

   # Search network device list for target6
   my @devList;
   for my $d (keys %$routes) {
      for my $i (@{$routes->{$d}}) {
         my ($net, $mask) = split('/', $i->{destination});
         $net = Net::IPv6Addr->new($net)->to_string_preferred;
         if (_is_in_network($dst, $net, $mask)) {
            push @devList, $i->{interface};
         }
      }
   }

   # If multiple devices found, we return all of them
   if (@devList > 1) {
      my @devs = map { intf_get($_) } @devList;
      return \@devs;
   }

   intf_get($devList[0]);
}

1;

__END__

=head1 NAME

Net::Libdnet6 - adds IPv6 support to Net::Libdnet

=head1 DESCRIPTION

=head1 SEE ALSO

L<Net::Libdnet>

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of the Artistic license.
See LICENSE.Artistic file in the source distribution archive.

=cut
