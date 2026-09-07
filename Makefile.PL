use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Data::NExT',
    AUTHOR           => 'Billy Lyrical <billy.lyrical@gmail.com>',
    VERSION_FROM     => 'lib/Data/NExT.pm',
    ABSTRACT_FROM    => 'lib/Data/NExT.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010',
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {},
    },
    PREREQ_PM        => {},
    TEST_REQUIRES    => {
        'Test::More' => '0.96',
    },
    BUILD_REQUIRES   => {},
    dist             => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    clean            => { FILES    => 'NExT-*' },
);
