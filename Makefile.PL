#
# $Id: Makefile.PL,v 1.1 2006/12/24 13:52:23 gomor Exp $
#
use ExtUtils::MakeMaker;

require v5.6.1;

WriteMakefile(
   NAME          => 'Net::Libdnet6',
   LICENSE       => 'Artistic',
   VERSION_FROM  => 'lib/Net/Libdnet6.pm',
   ABSTRACT_FROM => 'lib/Net/Libdnet6.pm',
   AUTHOR        => 'GomoR <perl@gomor.org>',
   PREREQ_PM     => {
      Net::Libdnet  => 0,
      Net::IPv6Addr => 0,
   },
);
