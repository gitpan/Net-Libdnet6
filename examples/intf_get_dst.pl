#!/usr/bin/perl
use strict;
use warnings;

my $dst = shift || die("Specify target host\n");

use Data::Dumper;
use Net::Libdnet6;

my $h = intf_get_dst($dst);
print Dumper($h)."\n";
