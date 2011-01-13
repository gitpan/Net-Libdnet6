#
# $Id: Makefile.PL 1678 2011-01-12 12:39:13Z gomor $
#
use ExtUtils::MakeMaker;

require v5.6.1;

WriteMakefile(
   NAME          => 'Net::Libdnet6',
   LICENSE       => 'artistic',
   VERSION_FROM  => 'lib/Net/Libdnet6.pm',
   ABSTRACT_FROM => 'lib/Net/Libdnet6.pm',
   AUTHOR        => 'GomoR <gomor-cpan_at_gomor.org>',
   PREREQ_PM     => {
      Net::Libdnet  => 0,
      Net::IPv6Addr => 0,
   },
);
