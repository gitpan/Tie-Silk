use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
              AUTHOR            => 'Theo Lengyel <dirt@cpan.org>',
              NAME		=> 'Tie::Silk',
              VERSION_FROM	=> 'Silk.pm',
              ABSTRACT_FROM     => 'Silk.pm',
              PREREQ_PM		=> { 'Log::Easy' => '.01',
                                   },
              PM                => { 'Silk.pm' => '$(INST_LIBDIR)/Silk.pm'},
             );
