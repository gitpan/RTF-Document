require 5.005;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'RTF::Document',
    'PREREQ_PM' => { 'Convert::Units::Type' => '0.33' },
    'VERSION_FROM' => 'Document.pm', # finds $VERSION
);

