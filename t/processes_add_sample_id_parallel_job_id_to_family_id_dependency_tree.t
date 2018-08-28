#!/usr/bin/env perl

#### Copyright 2017 Henrik Stranneheim

use Modern::Perl qw{2014};
use warnings qw{FATAL utf8};
use autodie;
use 5.018;    #Require at least perl 5.18
use utf8;
use open qw{ :encoding(UTF-8) :std };
use charnames qw{ :full :short };
use Carp;
use English qw{-no_match_vars};
use Params::Check qw{check allow last_error};

use FindBin qw{$Bin};    #Find directory of script
use File::Basename qw{dirname basename};
use File::Spec::Functions qw{catdir};
use Getopt::Long;
use Test::More;
use Readonly;

## MIPs lib/
use lib catdir( dirname($Bin), 'lib' );
use MIP::Script::Utils qw{help};

our $USAGE = build_usage( {} );

##Constants
Readonly my $NEWLINE    => qq{\n};
Readonly my $SPACE      => q{ };
Readonly my $UNDERSCORE => q{_};

my $VERBOSE = 1;
our $VERSION = q{1.0.0};

###User Options
GetOptions(
    'h|help' => sub {
        done_testing();
        say {*STDOUT} $USAGE;
        exit;
    },    #Display help text
    'v|version' => sub {
        done_testing();
        say {*STDOUT} $NEWLINE . basename($PROGRAM_NAME) . $SPACE . $VERSION,
          $NEWLINE;
        exit;
    },    #Display version number
    'vb|verbose' => $VERBOSE,
  )
  or (
    done_testing(),
    help(
        {
            USAGE     => $USAGE,
            exit_code => 1,
        }
    )
  );

BEGIN {

### Check all internal dependency modules and imports

    ## Modules with import
    my %perl_module;

    $perl_module{'MIP::Script::Utils'} = [qw{help}];

  MODULES:
    while ( my ( $module, $module_import ) = each %perl_module ) {
        use_ok( $module, @{$module_import} )
          or BAIL_OUT q{Cannot load } . $module;
    }

    ## Modules
    my @modules = ('MIP::Processmanagement::Processes');

  MODULES:
    for my $module (@modules) {
        require_ok($module) or BAIL_OUT q{Cannot load } . $module;
    }
}

use MIP::Processmanagement::Processes
  qw{add_sample_id_parallel_job_id_to_family_id_dependency_tree};

diag(
"Test add_sample_id_parallel_job_id_to_family_id_dependency_tree $MIP::Processmanagement::Processes::VERSION, Perl $^V, $EXECUTABLE_NAME"
);

## Base arguments
my $family_id           = q{family1};
my $sample_id           = q{sample2};
my $path                = q{MAIN};
my $family_id_chain_key = $family_id . $UNDERSCORE . $path;
my $sample_id_chain_key = $sample_id . $UNDERSCORE . $path;
my $infile_index        = 0;
my $sample_id_parallel_chain_key =
  $sample_id . $UNDERSCORE . q{parallel} . $UNDERSCORE . $path . $infile_index;

my %infile_lane_prefix = (
    sample1 => [qw{1_lane1 1_lane2}],
    sample2 => [qw{2_lane1}],
    sample3 => [qw{3_lane4 3_lane5}],
);

my %job_id = (
    $family_id_chain_key => {
        $sample_id_chain_key          => [qw{job_id_1 job_id_2}],
        q{sample2_MAIN}               => [qw{job_id_3}],
        q{sample3_MAIN}               => [qw{job_id_4 job_id_5}],
        $sample_id_parallel_chain_key => [qw{job_id_10 job_id_11}],
        $family_id_chain_key          => [qw{job_id_6}],
    },
);

### Parallel jobs

add_sample_id_parallel_job_id_to_family_id_dependency_tree(
    {
        job_id_href             => \%job_id,
        infile_lane_prefix_href => \%infile_lane_prefix,
        family_id_chain_key     => $family_id_chain_key,
        sample_id               => $sample_id . q{no_parallel},
        path                    => $path,
    }
);

my $no_push_result = join $SPACE,
  @{ $job_id{$family_id_chain_key}{$family_id_chain_key} };
is( $no_push_result, q{job_id_6}, q{No sample_id parallel job_ids} );

add_sample_id_parallel_job_id_to_family_id_dependency_tree(
    {
        job_id_href             => \%job_id,
        infile_lane_prefix_href => \%infile_lane_prefix,
        family_id_chain_key     => $family_id_chain_key,
        sample_id               => $sample_id,
        path                    => $path,
    }
);

my $sample_id_parallel_push_result = join $SPACE,
  @{ $job_id{$family_id_chain_key}{$family_id_chain_key} };
is(
    $sample_id_parallel_push_result,
    q{job_id_6 job_id_10 job_id_11},
    q{Pushed parallel job_id to sample_id}
);

done_testing();

######################
####SubRoutines#######
######################

sub build_usage {

##build_usage

##Function : Build the USAGE instructions
##Returns  : ""
##Arguments: $program_name
##         : $program_name => Name of the script

    my ($arg_href) = @_;

    ## Default(s)
    my $program_name;

    my $tmpl = {
        program_name => {
            default     => basename($PROGRAM_NAME),
            strict_type => 1,
            store       => \$program_name,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak qw{Could not parse arguments!};

    return <<"END_USAGE";
 $program_name [options]
    -vb/--verbose Verbose
    -h/--help Display this help message
    -v/--version Display version
END_USAGE
}
