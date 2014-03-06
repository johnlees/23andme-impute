#!/usr/bin/perl -w

use strict;

use Getopt::Long;

# Allow status updates without a newline
use IO::Handle;
STDOUT->autoflush(1);

# Sex table
my %sex_table = ("0" => "male",
                 "1" => "female",
                 "2" => "unknown");

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

# Best to make as a sub, then call from another script while also providing
# functionality to work as a stand-alone script
sub twentythree_to_gen($$$)
{
   my ($input_file, $output_prefix, $sex) = @_;

   if (!-e $input_file)
   {
      print("Input file does not exist!\n\n");
   }
   else
   {
      my $current_chromosome = 0;
      my $i = 1;
      print("Printing chromosome: ");

      open(INPUT, $input_file) || die ("Could not open $input_file for reading\n");

      while (my $in_line = <INPUT>)
      {
         chomp($in_line);

         if ($in_line !~ /^\#.*$/)
         {
            my ($rsid, $chromosome, $position, $genotype) = split(/\s+/, $in_line);

            # Start each new chromosome in a new file
            if ($chromosome ne $current_chromosome)
            {
               if ($chromosome eq "Y" && $sex == 1)
               {
                  # Skip for women
                  last;
               }
               elsif ($current_chromosome eq "Y" && $sex == 2)
               {
                  # If sex is undefined, delete the Y chromosome if it's empty
                  my $Y_file_name = $output_prefix . "chrY.gen";
                  if(! -s $Y_file_name)
                  {
                     $sex = 1;
                     unlink ($Y_file_name);
                  }
                  else
                  {
                     $sex = 0;
                  }

                  last;
               }
               elsif ($chromosome eq "MT")
               {
                  last;
               }

               print STDOUT "$chromosome ";

               $i = 1;
               unless($chromosome eq "1")
               {
                  close OUTPUT;
               }
               my $outfile = $output_prefix . "chr$chromosome.gen";
               open(OUTPUT, ">$outfile") || die ("Could not open $outfile for writing\n");

            }

            # Get major and minor allele
            # TODO: Do I need to check which is major and minor allele in the
            # reference?
            my ($a0, $a1, $gt);
            if ($genotype =~ /^(A|T|G|C)(A|T|G|C)$/)
            {
               # Note this only deals with SNPs. Also reported are missing -,
               # deletions D and insertions I. For now we ignore them, as
               # IMPUTE2 works from SNPs only, though these sites could be put
               # back in at the end
               $a0 = $1;
               $a1 = $2;

               if ($a0 eq $a1)
               {
                  # TODO: Will need to set an arbitrary alt allele at homs
                  # $a1 = ;
                  $gt = "0 0 1";
               }
               else
               {
                  $gt = "1 0 0";
               }

               print OUTPUT "SNP$i $rsid $position $a0 $a1 $gt\n";
            }

            $current_chromosome = $chromosome;
            $i++;
         }
      }
      print ("\n");
      close INPUT;
      close OUTPUT;
   }

   return($sex);

}

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
   # Set option defaults if necessary
   if (!defined($output_prefix))
   {
      if ($input_file =~ /(.*)\.txt$/)
      {
         $output_prefix = $1;
      }
      else
      {
         $output_prefix = $input_file;
      }
   }

   if (defined($sex))
   {
      if ($sex eq "male" || $sex eq "m")
      {
         $sex = 0;
      }
      elsif ($sex eq "female" || $sex eq "f")
      {
         $sex = 1;
      }
   }
   if (!defined($sex) || ($sex ne "0" && $sex ne "1"))
   {
         $sex = 2;
   }

   print "Inputs:\n";
   print "\t Input file:     $input_file\n";
   print "\t Output prefix:  $output_prefix\n";
   print "\t Sex:            $sex_table{$sex}\n\n";

   my $new_sex = twentythree_to_gen($input_file, $output_prefix, $sex);

   if ($new_sex != $sex)
   {
      if ($new_sex == 0)
      {
         $sex = "male";
      }
      else
      {
         $sex = "female";
      }
      print("No sex input, inferred $sex.\n");
   }

   print "Done.\n";
}

exit(0);
