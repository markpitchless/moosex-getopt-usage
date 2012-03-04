use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'MooseX::Getopt::Usage',
    license             => 'perl',
    dist_author         => q{Mark Pitchless <markpitchless@gmail.com>},
    dist_version_from   => 'lib/MooseX/Getopt/Usage.pm',
    requires => {
        'Moose' => 1.23,
        'MooseX::Method::Signatures' => 0.36,
        'Term::ANSIColor' => 0,
        'Term::ReadKey'   => 0,
        'Text::Wrap'      => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup     => [ 'MooseX-Getopt-Usage-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
