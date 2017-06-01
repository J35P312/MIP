package MIP::Workloadmanager::Slurm;

#### Copyright 2017 Henrik Stranneheim

use strict;
use warnings;
use warnings qw(FATAL utf8);
use utf8;    #Allow unicode characters in this script
use open qw( :encoding(UTF-8) :std );
use charnames qw( :full :short );
use Carp;
use autodie;

BEGIN {

    use base qw(Exporter);
    require Exporter;

    # Set the version for version checking
    our $VERSION = 1.01;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw(sacct);
}

use Params::Check qw[check allow last_error];
$Params::Check::PRESERVE_CASE = 1;    #Do not convert to lower case

sub sacct {

##sacct

##Function : Perl wrapper for writing SLURM sacct recipe to already open $FILEHANDLE or return commands array. Based on SLURM sacct 2.6.0.
##Returns  : "@commands"
##Arguments: $fields_format_ref, $job_ids_ref, $stderrfile_path, $stdoutfile_path, $FILEHANDLE, $append_stderr_info,
##         : $job_ids_ref        => Slurm job id
##         : $fields_format_ref  => List of format fields
##         : $stderrfile_path    => Stderrfile path
##         : $stdoutfile_path    => Stdoutfile path
##         : $FILEHANDLE         => Filehandle to write to
##         : $append_stderr_info => Append stderr info to file

    my ($arg_href) = @_;

    ## Default(s)
    my $append_stderr_info;

    ## Flatten argument(s)
    my $fields_format_ref;
    my $job_ids_ref;
    my $stderrfile_path;
    my $stdoutfile_path;
    my $FILEHANDLE;

    my $tmpl = {
        fields_format_ref =>
          { default => [], strict_type => 1, store => \$fields_format_ref },
        job_ids_ref =>
          { default => [], strict_type => 1, store => \$job_ids_ref },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path },
        FILEHANDLE         => { store => \$FILEHANDLE },
        append_stderr_info => {
            default     => 0,
            allow       => [ 0, 1 ],
            strict_type => 1,
            store       => \$append_stderr_info
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak qw{Could not parse arguments!};

    my $SPACE = q{ };
    my $COMMA = q{,};

    ## sacct
    my @commands = qw(sacct);    #Stores commands depending on input parameters

    ## Options
    if ( @{$fields_format_ref} ) {

        push @commands, '--format=' . join $COMMA, @{$fields_format_ref};
    }
    if ( @{$job_ids_ref} ) {

        push @commands, '--jobs ' . join $COMMA, @{$job_ids_ref};
    }
    if ($stdoutfile_path) {

        # Redirect stdout to program specific stdout file
        push @commands, '1> ' . $stdoutfile_path;
    }
    if ($stderrfile_path) {

        if ($append_stderr_info) {

            # Redirect and append stderr output to program specific stderr file
            push @commands, '2>> ' . $stderrfile_path;
        }
        else {

            # Redirect stderr output to program specific stderr file
            push @commands, '2> ' . $stderrfile_path;
        }
    }
    if ($FILEHANDLE) {

        print {$FILEHANDLE} join( $SPACE, @commands ) . $SPACE;
    }
    return @commands;
}

1;
