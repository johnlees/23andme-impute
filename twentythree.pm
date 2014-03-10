#!/usr/bin/perl -w

package twentythree;

use strict;
use warnings;

# Allow status updates without a newline
use IO::Handle;
STDOUT->autoflush(1);

our %sex_table = ("0" => "male",
                 "1" => "female",
                 "2" => "unknown");

# Converts from 23andme raw data to .gen files for each chromosome, outputting
# status to stdout
sub format_convert($$$)
{
   my ($input_file,$output_prefix,$sex) = @_;

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
   print "\t Sex:            $twentythree::sex_table{$sex}\n\n";

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

   return($sex);
}

# Function to actually do the conversion from 23->gen
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
                  # Will need to set an arbitrary alt allele at homs, if
                  # it doesn't need to be the same as the reference panel a0
                  # and a1 this is actually better and easier
                  if ($a0 ne "A")
                  {
                     $a1 = "A";
                  }
                  else
                  {
                     $a1 = "T";
                  }

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

1;
