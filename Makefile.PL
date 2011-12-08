use 5.010;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'HeliosX::JSService',
    VERSION_FROM      => 'lib/HeliosX/JSService.pm', # finds $VERSION
    PREREQ_PM         => {
							Helios => 2.20,
							JSPL   => 1.04,
                         }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/HeliosX/JSService.pm', # retrieve abstract from module
       AUTHOR         => 'Andrew Johnson <lajandy at cpan dot org>') : ()),
);
