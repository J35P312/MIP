#!/usr/bin/env perl

use 5.026;
use Carp;
use charnames qw{ :full :short };
use English qw{ -no_match_vars };
use File::Basename qw{ dirname  };
use File::Spec::Functions qw{ catdir catfile };
use FindBin qw{ $Bin };
use open qw{ :encoding(UTF-8) :std };
use Params::Check qw{ allow check last_error };
use Test::More;
use utf8;
use warnings qw{ FATAL utf8 };

## CPANM
use autodie qw{ :all };
use Modern::Perl qw{ 2018 };
use Readonly;

## MIPs lib/
use lib catdir( dirname($Bin), q{lib} );
use MIP::Constants qw{ $COMMA $SPACE };
use MIP::Test::Commands qw{ test_function };
use MIP::Test::Fixtures qw{ test_standard_cli };

my $VERBOSE = 1;
our $VERSION = 1.01;

$VERBOSE = test_standard_cli(
    {
        verbose => $VERBOSE,
        version => $VERSION,
    }
);

BEGIN {
    use MIP::Test::Fixtures qw{ test_import };
    ### Check all internal dependency modules and imports
## Modules with import
    my %perl_module = (
        q{MIP::Program::Gatk}  => [qw{ gatk_gathervcfscloud }],
        q{MIP::Test::Fixtures} => [qw{ test_standard_cli }],
    );

    test_import( { perl_module_href => \%perl_module, } );
}

use MIP::Program::Gatk qw{ gatk_gathervcfscloud };

diag(   q{Test gatk_gathervcfscloud from Gatk.pm v}
      . $MIP::Program::Gatk::VERSION
      . $COMMA
      . $SPACE . q{Perl}
      . $SPACE
      . $PERL_VERSION
      . $SPACE
      . $EXECUTABLE_NAME );

## Base arguments
my @function_base_commands = qw{ gatk GatherVcfsCloud };

my %base_argument = (
    filehandle => {
        input           => undef,
        expected_output => \@function_base_commands,
    },
    stderrfile_path => {
        input           => q{stderrfile.test},
        expected_output => q{2> stderrfile.test},
    },
);

## Can be duplicated with %base_argument and/or %specific_argument
## to enable testing of each individual argument
my %required_argument = (
    infile_paths_ref => {
        inputs_ref =>
          [ catfile(qw{ path to case_chr1.vcf }), catfile(qw{ path to case_chr2.vcf }) ],
        expected_output => q{--input}
          . $SPACE
          . catfile(qw{ path to case_chr1.vcf})
          . $SPACE
          . q{--input}
          . $SPACE
          . catfile(qw{ path to case_chr2.vcf}),
    },
    outfile_path => {
        input           => catfile(qw{ path to case.vcf }),
        expected_output => q{--output } . catfile(qw{ path to case.vcf }),
    },
);

my %specific_argument = (
    ignore_safety_checks => {
        input           => 1,
        expected_output => q{--ignore-safety-checks},
    },
    infile_paths_ref => {
        inputs_ref =>
          [ catfile(qw{ path to case_chr1.vcf }), catfile(qw{ path to case_chr2.vcf }) ],
        expected_output => q{--input}
          . $SPACE
          . catfile(qw{ path to case_chr1.vcf})
          . $SPACE
          . q{--input}
          . $SPACE
          . catfile(qw{ path to case_chr2.vcf}),
    },
    outfile_path => {
        input           => catfile(qw{ path to case.vcf }),
        expected_output => q{--output } . catfile(qw{ path to case.vcf }),
    },
);

## Coderef - enables generalized use of generate call
my $module_function_cref = \&gatk_gathervcfscloud;

## Test both base and function specific arguments
my @arguments = ( \%base_argument, \%specific_argument );

ARGUMENT_HASH_REF:
foreach my $argument_href (@arguments) {
    my @commands = test_function(
        {
            argument_href              => $argument_href,
            base_commands_index        => 1,
            do_test_base_command       => 1,
            function_base_commands_ref => \@function_base_commands,
            module_function_cref       => $module_function_cref,
            required_argument_href     => \%required_argument,
        }
    );
}

done_testing();
