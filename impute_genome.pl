#!/usr/bin/perl -w

use strict;
use warnings;

use twentythree;

# A wrapper script for the whole imputation
# Should allow IMPUTE2 commands to be output as shell scripts, to stdout, or
# actually run (with number of simult jobs specified)
#
# Use sub from file conversion to get into .gen format
# Break up into 5Mb chunks, get length from .legend files
# Use -phase to get .hap out
# TODO: Later: then impute with pbwt to improve accuracy
# Put back together into a nice format (either 23 and me or vcf)
#
# Final output:
# Whole genome
# Phased 23andme

my $help_message = <<END;
Usage: impute_genome.pl -i <input_file> [-o <output_prefix> -s <sex>]
[<impute_options>]

Imputes whole genome SNPs from the raw data of ~450 000 SNPs typed by
23andme, and also phases the typed sites.
This is a computationally heavy task, and so running output commands in
parallel is recommended.

   <input_options>
   -i, --input    The 'raw data' file from 23 and me, which has four tab
                  separated columns: rsid, chromosome, position, genotype
   -o, --output   The prefix for the output .gen files (default is the
                  input name)
   -s, --sex      The sex of the subject, either male (m) or female (f). If
                  omitted a guess will be made based on presence of Y
                  chromosome sites

   <impute_options>:
   -r, --run <threads>
                  Directly execute the imputation, but note this requires
                  a lot of memory and CPU time. Optionally supply an
                  integer number of jobs to simultaneously
                  execute. This should be <= number of cores, but this is
                  not checked
   -p, --print    Print the imputation commands to STDOUT rather than
                  executing them - default behaviour
   -w, --write    Write to commands to shell scripts, for execution later
                  by a job scheduling system

   <other>
   -h, --help     Displays this help message

END

#****************************************************************************************#
#* Main                                                                                 *#
#****************************************************************************************#

#* Gets input parameters
my ($input_file, $output_prefix, $sex, $run, $print, $write, $help);
GetOptions ("input|i=s"  => \$input_file,
            "output|o=s" => \$output_prefix,
            "sex|s=s"  => \$sex,
            "run|r:i" => \$run,
            "print|p" => \$print,
            "write|w" => \$write,
            "help|h"     => \$help
		   ) or die($help_message);

# Check necessary files exist
if (defined($help))
{
   print $help_message;
}
else
{
   # Impute here

}

exit(0);
