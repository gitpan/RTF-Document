require 5.005;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'RTF::Document',
    'VERSION_FROM' => 'Document.pm', # finds $VERSION
);
