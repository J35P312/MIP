#!/usr/bin/env perl

use 5.026;
use Carp;
use charnames qw{ :full :short };
use English qw{ -no_match_vars };
use open qw{ :encoding(UTF-8) :std };
use File::Basename qw{ basename dirname };
use File::Spec::Functions qw{ catdir catfile };
use FindBin qw{ $Bin };
use Getopt::Long;
use Params::Check qw{ allow check last_error };
use Test::More;
use utf8;
use warnings qw{ FATAL utf8 };

## CPANM
use autodie qw { :all };
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
        q{MIP::Program::Alignment::Star} => [qw{ star_aln }],
        q{MIP::Test::Fixtures}           => [qw{ test_standard_cli }],
    );

    test_import( { perl_module_href => \%perl_module, } );
}

use MIP::Program::Alignment::Star qw{ star_aln };

diag(   q{Test star_aln from Star.pm v}
      . $MIP::Program::Alignment::Star::VERSION
      . $COMMA
      . $SPACE . q{Perl}
      . $SPACE
      . $PERL_VERSION
      . $SPACE
      . $EXECUTABLE_NAME );

## Constants
Readonly my $ALIGN_INTRON_MAX           => 100_000;
Readonly my $ALIGN_MATES_GAP_MAX        => 100_000;
Readonly my $ALIGN_SJDB_OVERHANG_MIN    => 10;
Readonly my $CHIM_JUNCTION_OVERHANG_MIN => 12;
Readonly my $CHIM_SEGMENT_MIN           => 12;
Readonly my $CHIM_SEGMENT_READ_GAP_MAX  => 3;
Readonly my $LIMIT_BAM_SORT_RAM         => 315_321_372_30;
Readonly my $PE_OVERLAP_NBASES_MIN      => 10;
Readonly my $THREAD_NUMBER              => 16;

my @function_base_commands = qw{ STAR };

my %base_argument = (
    stdoutfile_path => {
        input           => q{stdoutfile.test},
        expected_output => q{1> stdoutfile.test},
    },
    stderrfile_path => {
        input           => q{stderrfile.test},
        expected_output => q{2> stderrfile.test},
    },
    stderrfile_path_append => {
        input           => q{stderrfile.test},
        expected_output => q{2>> stderrfile.test},
    },
    filehandle => {
        input           => undef,
        expected_output => \@function_base_commands,
    },
);

my %required_argument = (
    genome_dir_path => {
        input           => catfile(qw{ dir genome_dir_path }),
        expected_output => q{--genomeDir} . $SPACE . catfile(qw{ dir genome_dir_path }),
    },
    infile_paths_ref => {
        inputs_ref      => [ catfile(qw{ dir r1.fq.gz }), catfile(qw{ dir r2.fq.gz }) ],
        expected_output => q{--readFilesIn}
          . $SPACE
          . catfile(qw{ dir r1.fq.gz })
          . $SPACE
          . catfile(qw{ dir r2.fq.gz }),
    },
    outfile_name_prefix => {
        input           => catfile(qw{ dir test }),
        expected_output => q{--outFileNamePrefix} . $SPACE . catfile(qw{ dir test }),
    },
    out_sam_type => {
        input           => q{BAM SortedByCoordinate},
        expected_output => q{--outSAMtype} . $SPACE . q{BAM SortedByCoordinate},
    },
    read_files_command => {
        input           => q{gzip} . $SPACE . q{-c},
        expected_output => q{--readFilesCommand} . $SPACE . q{gzip} . $SPACE . q{-c},
    },
);

my %specific_argument = (
    align_intron_max => {
        input           => $ALIGN_INTRON_MAX,
        expected_output => q{--alignIntronMax} . $SPACE . $ALIGN_INTRON_MAX,
    },
    align_mates_gap_max => {
        input           => $ALIGN_MATES_GAP_MAX,
        expected_output => q{--alignMatesGapMax} . $SPACE . $ALIGN_MATES_GAP_MAX,
    },
    align_sjdb_overhang_min => {
        input           => $ALIGN_SJDB_OVERHANG_MIN,
        expected_output => q{--alignSJDBoverhangMin} . $SPACE . $ALIGN_SJDB_OVERHANG_MIN,
    },
    chim_junction_overhang_min => {
        input           => $CHIM_JUNCTION_OVERHANG_MIN,
        expected_output => q{--chimJunctionOverhangMin}
          . $SPACE
          . $CHIM_JUNCTION_OVERHANG_MIN,
    },
    chim_out_type => {
        input           => q{WithinBAM},
        expected_output => q{--chimOutType} . $SPACE . q{WithinBAM},
    },
    chim_segment_min => {
        input           => $CHIM_SEGMENT_MIN,
        expected_output => q{--chimSegmentMin} . $SPACE . $CHIM_SEGMENT_MIN,
    },
    chim_segment_read_gap_max => {
        input           => $CHIM_SEGMENT_READ_GAP_MAX,
        expected_output => q{--chimSegmentReadGapMax}
          . $SPACE
          . $CHIM_SEGMENT_READ_GAP_MAX,
    },
    infile_paths_ref => {
        inputs_ref      => [ catfile(qw{ dir r1.fq.gz }), catfile(qw{ dir r2.fq.gz }) ],
        expected_output => q{--readFilesIn}
          . $SPACE
          . catfile(qw{ dir r1.fq.gz })
          . $SPACE
          . catfile(qw{ dir r2.fq.gz }),
    },
    limit_bam_sort_ram => {
        input           => $LIMIT_BAM_SORT_RAM,
        expected_output => q{--limitBAMsortRAM} . $SPACE . $LIMIT_BAM_SORT_RAM,
    },
    outfile_name_prefix => {
        input           => catfile(qw{ dir test }),
        expected_output => q{--outFileNamePrefix} . $SPACE . catfile(qw{ dir test }),
    },
    out_sam_strand_field => {
        input           => q{intronMotif},
        expected_output => q{--outSAMstrandField} . $SPACE . q{intronMotif},
    },
    out_sam_type => {
        input           => q{BAM SortedByCoordinate},
        expected_output => q{--outSAMtype} . $SPACE . q{BAM SortedByCoordinate},
    },
    pe_overlap_nbases_min => {
        input           => $PE_OVERLAP_NBASES_MIN,
        expected_output => q{--peOverlapNbasesMin} . $SPACE . $PE_OVERLAP_NBASES_MIN,
    },
    quant_mode => {
        input           => q{GeneCounts},
        expected_output => q{--quantMode} . $SPACE . q{GeneCounts},
    },
    read_files_command => {
        input           => q{gunzip} . $SPACE . q{-c},
        expected_output => q{--readFilesCommand} . $SPACE . q{gunzip} . $SPACE . q{-c},
    },
    thread_number => {
        input           => $THREAD_NUMBER,
        expected_output => q{--runThreadN} . $SPACE . $THREAD_NUMBER,
    },
    two_pass_mode => {
        input           => q{Basic},
        expected_output => q{--twopassMode} . $SPACE . q{Basic},
    },
);

my $module_function_cref = \&star_aln;

my @arguments = ( \%base_argument, \%specific_argument );

ARGUMENT_HASH_REF:

foreach my $argument_href (@arguments) {
    my @commands = test_function(
        {
            argument_href              => $argument_href,
            required_argument_href     => \%required_argument,
            module_function_cref       => $module_function_cref,
            function_base_commands_ref => \@function_base_commands,
            do_test_base_command       => 1,
        }
    );
}

done_testing();
