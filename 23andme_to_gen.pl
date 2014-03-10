#!/usr/bin/perl -w
#
# Wrapper script to allow format conversion without performing full imputation
#

use strict;
use warnings;

use Getopt::Long;

# Allow status updates without a newline
use IO::Handle;
STDOUT->autoflush(1);

use twentythree;

my $help_message = <<END;
Usage: 23andme_to_gen.pl -i <input_file> -o <output_prefix> -s <sex>
Converts the raw data output from 23 and me to .gen files for each
chromosome

   -i, --input    The 'raw data' file from 23 and me, which has four tab
                  separated columns: rsid, chromosome, position, genotype
   -o, --output   The prefix for the output .gen files (default is the
                  input name)
   -s, --sex      The sex of the subject, either male (m) or female (f). If
                  omitted a guess will be made based on presence of Y
                  chromosome sites
   -h, --help     Displays this help message

END

#****************************************************************************************#
#* Main                                                                                 *#
#****************************************************************************************#

#* Gets input parameters
my ($input_file, $output_prefix, $sex, $help);
GetOptions ("input|i=s"  => \$input_file,
            "output|o=s" => \$output_prefix,
            "sex|s=s"  => \$sex,
            "help|h"     => \$help
		   ) or die($help_message);

# Check necessary files exist
if (defined($help))
{
   print $help_message;
}
elsif (!defined($input_file))
{
	print ("Input file does not exist!\n\n");
	print $help_message;
}
else
{
   #Convert
   my $sex = twentythree::format_convert($input_file, $output_prefix, $sex);
}

print "Done.\n";

exit(0);
