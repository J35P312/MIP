package MIP::Recipes::Split_fastq_file;

use strict;
use warnings;
use warnings qw{ FATAL utf8 };
use utf8;
use open qw{ :encoding(UTF-8) :std };
use autodie qw{:all};
use charnames qw{ :full :short };
use Carp;
use English qw{ -no_match_vars };
use Params::Check qw{ check allow last_error };
use File::Basename qw(fileparse);
use File::Spec::Functions qw(catdir catfile);

## CPANM
use Readonly;

BEGIN {

    require Exporter;
    use base qw{Exporter};

    # Set the version for version checking
    our $VERSION = 1.00;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw(analysis_split_fastq_file);

}

##Constants
Readonly my $ASTERIX      => q{*};
Readonly my $DOT     => q{.};
Readonly my $NEWLINE => qq{\n};
Readonly my $PIPE         => q{|};
Readonly my $SPACE        => q{ };
Readonly my $UNDERSCORE   => q{_};

sub analysis_split_fastq_file {

##analysis_split_fastq_file

##Function : Split input fastq files into batches of reads, versions and compress. Moves original file to subdirectory.
##Returns  : ""
##Arguments: $parameter_href, $active_parameter_href, $infile_href, $job_id_href, $insample_directory, $outsample_directory, $sample_id, $program_name, $sequence_read_batch, $temp_directory
##         : $parameter_href          => Parameter hash {REF}
##         : $active_parameter_href   => Active parameters for this analysis hash {REF}
##         : $infile_href             => Infiles hash {REF}
##         : $job_id_href             => Job id hash {REF}
##         : $insample_directory      => In sample directory
##         : $outsample_directory     => Out sample directory
##         : $sample_id               => Sample id
##         : $program_name            => Program name
##         : $sequence_read_batch     => Number of sequences in each fastq batch
##         : $temp_directory          => Temporary directory

    my ($arg_href) = @_;

    ## Default(s)
    my $family_id_ref;
    my $temp_directory;
    my $sequence_read_batch;

    ## Flatten argument(s)
    my $parameter_href;
    my $active_parameter_href;
    my $infile_href;
    my $job_id_href;
    my $insample_directory;
    my $outsample_directory;
    my $sample_id;
    my $program_name;

    my $tmpl = {
        parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$parameter_href
        },
        active_parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$active_parameter_href
        },
        infile_href => {
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$infile_href
        },
        job_id_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$job_id_href
        },
		insample_directory => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$insample_directory
        },
        outsample_directory => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$outsample_directory
        },
        sample_id => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$sample_id
        },
        program_name => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$program_name
        },
        family_id_ref => {
            default     => \$arg_href->{active_parameter_href}{family_id},
            strict_type => 1,
            store       => \$family_id_ref
        },
        temp_directory => {
            default     => $arg_href->{active_parameter_href}{temp_directory},
            strict_type => 1,
            store       => \$temp_directory
        },
        sequence_read_batch => {
            default     => 2500000,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$sequence_read_batch
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    use MIP::Script::Setup_script qw(setup_script);
    use MIP::IO::Files qw(migrate_file);
    use MIP::Gnu::Coreutils qw(gnu_cp gnu_rm gnu_mv gnu_split gnu_mkdir);
    use MIP::Program::Compression::Pigz qw(pigz);

    ## Retrieve logger object
    my $log = Log::Log4perl->get_logger(q{MIP});

    my $mip_program_name = q{p} . $program_name;
    my $mip_program_mode = $active_parameter_href->{$mip_program_name};

    ## Alias
    my $job_id_chain = $parameter_href->{$mip_program_name}{chain};
    my $core_number =
      $active_parameter_href->{module_core_number}{$mip_program_name};
    my $time =
      $active_parameter_href->{module_time}{$mip_program_name};

    ## Filehandles
    # Create anonymous filehandle
    my $FILEHANDLE = IO::Handle->new();

    foreach my $fastq_file ( @{ $infile_href->{$sample_id} } ) {

        ## Creates program directories (info & programData & programScript), program script filenames and writes sbatch header
        my ($file_name) = setup_script(
            {
                active_parameter_href => $active_parameter_href,
                job_id_href           => $job_id_href,
                FILEHANDLE            => $FILEHANDLE,
                directory_id          => $sample_id,
                program_name          => $program_name,
                program_directory     => lc($program_name),
                core_number           => $core_number,
                process_time => $time,
                temp_directory => $temp_directory,
            }
        );

        ## Assign file_tags
        my $infile_path = catfile( $insample_directory,  $fastq_file );
        my $file_path   = catfile( $temp_directory, $fastq_file );

        ## Assign suffix
        my $infile_suffix =
          $parameter_href->{$mip_program_name}{infile_suffix};
        my $outfile_suffix = get_file_suffix(
            {
                parameter_href => $parameter_href,
                suffix_key     => q{outfile_suffix},
                program_name   => $mip_program_name,
            }
        );

        say $FILEHANDLE q{## } . $program_name;

        my %fastq_file_info;

        ## Detect fastq file info for later rebuild of filename
        if ( $fastq_file =~
            /(\d+)_(\d+)_([^_]+)_([^_]+)_([^_]+)_(\d)$infile_suffix/ )
        {

            %fastq_file_info = (
                lane      => $1,
                date      => $2,
                flowcell  => $3,
                sample_id => $4,
                index     => $5,
                direction => $6,
            );
        }
        ## Removes ".file_ending" in filename.FILENDING(.gz)
        my $file_prefix =
          fileparse( $fastq_file, qr/$infile_suffix|$infile_suffix[.]gz/ )
          . $UNDERSCORE . q{splitted} . $UNDERSCORE;

        ## Copies file to temporary directory.
        migrate_file(
            {
                FILEHANDLE   => $FILEHANDLE,
                infile_path  => $infile_path,
                outfile_path => $temp_directory,
            }
        );
        say {$FILEHANDLE} q{wait} . $NEWLINE;

        ## Decompress file and split
        pigz(
            {
                infile_path => $file_path,
                decompress  => 1,
                processes   => $core_number,
                stdout      => 1,
                FILEHANDLE  => $FILEHANDLE,
            }
        );
        print $FILEHANDLE $PIPE . $SPACE;    #Pipe

        gnu_split(
            {
                infile_path      => q{-},
                lines            => ( $sequence_read_batch * 4 ),
                numeric_suffixes => 1,
                suffix_length    => 4,
                FILEHANDLE       => $FILEHANDLE,
                prefix => catfile( $temp_directory, $file_prefix ),
            }
        );
        say {$FILEHANDLE} $NEWLINE;

        ## Remove original files
        gnu_rm(
            {
                infile_path => $file_path,
                force       => 1,
                FILEHANDLE  => $FILEHANDLE,
            }
        );
	say {$FILEHANDLE} $NEWLINE;

        ## Find all splitted files
        say {$FILEHANDLE} q{splitted_files=(}
          . catfile( $temp_directory, q{*_splitted_*} )
          . q{)}, $NEWLINE;

        ## Iterate through array using a counter
        say {$FILEHANDLE}
q?for ((file_counter=0; file_counter<${#splitted_files[@]}; file_counter++)); do ?;

        ## Rename each element of array to include splitted suffix in flowcell id
        print {$FILEHANDLE} "\t" . q?mv ${splitted_files[$file_counter]} ?;
        print {$FILEHANDLE} catfile( $temp_directory, "" );
        print {$FILEHANDLE} $fastq_file_info{lane} . "_";
        print {$FILEHANDLE} $fastq_file_info{date} . "_";
        print {$FILEHANDLE} $fastq_file_info{flowcell} . q?"-SP"$file_counter"?;
        print {$FILEHANDLE} "_" . $fastq_file_info{sample_id} . "_";
        print {$FILEHANDLE} $fastq_file_info{index} . "_";
        print {$FILEHANDLE} $fastq_file_info{direction} . $infile_suffix;
        say {$FILEHANDLE} q?"?, "\n";

        say {$FILEHANDLE} "\t" . q?echo "${splitted_files[$file_counter]}" ?;
        say {$FILEHANDLE} "done";

        ## Compress file again
        pigz(
            {
                infile_path =>
                  catfile( $temp_directory, $ASTERIX . $infile_suffix ),
                FILEHANDLE => $FILEHANDLE,
            }
        );
        say {$FILEHANDLE} $NEWLINE;

        ## Copies files from temporary folder to source
        gnu_cp(
            {
                FILEHANDLE => $FILEHANDLE,
                infile_path =>
                  catfile( $temp_directory, q{*-SP*} . $outfile_suffix ),
                outfile_path => $outsample_directory,
            }
        );
        say {$FILEHANDLE} $NEWLINE;

        ## Move original file to not be included in subsequent analysis
        gnu_mkdir(
            {
                indirectory_path => $infile_path,
                parents          => 1,
                FILEHANDLE       => $FILEHANDLE,
            }
        );
        say {$FILEHANDLE} $NEWLINE;

        gnu_mv(
            {
                infile_path  => $infile_path,
                outfile_path => catfile(
                    $insample_directory, q{original_fastq_files},
                    $fastq_file
                ),
                FILEHANDLE => $FILEHANDLE,
            }
        );
        say {$FILEHANDLE} $NEWLINE;

        if ($mip_program_mode == 1) {

            slurm_submit_job_no_dependency_add_to_sample(
                {
                    job_id_href      => $job_id_href,
                    family_id        => $$family_id_ref,
                    sample_id        => $sample_id,
                    path             => $job_id_chain,
                    log              => $log,
                    sbatch_file_name => $file_name
                }
            );
        }
    }
    close $FILEHANDLE;
    return;
}

1;
