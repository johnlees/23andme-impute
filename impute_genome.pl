#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long;
use IO::Zlib;
use POSIX;

use twentythree;

# TODO: Later: then impute with pbwt to improve accuracy
# Put back together into a nice format (either 23 and me or vcf)
# (this could be done with pbwt)
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
   -g, --ref      Path to the folder that contains the imputation reference
                  haplotype and legend files. Default is current directory
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
#* Subs                                                                                 *#
#****************************************************************************************#
sub chrom_jobs($)
{
   my ($chrom_file) = @_;

   my $last_line;

   # Reading through zipped legend files prohibilitvely slow
   #tie (*LEGEND, 'IO::Zlib', $chrom_file, "rb") or die("Could not open $chrom_file\n");
   #while ($legend_line = <LEGEND>)
   #{
   #   # Get to end of file
   #}

   open(LEGEND, "gzip -dc $chrom_file |") or die("Could not open $chrom_file\n");
   while (my $legend_line = <LEGEND>)
   {
      # Get to end of file
      $last_line = $legend_line if eof;
   }

   my ($rsid, $position, $a0, $a1, $var_type, $seq_type, @pop_maf) = split(/\s+/, $last_line);
   my $num_jobs = ceil($position / $twentythree::chunk_length);

   close LEGEND;

   return($num_jobs);

}

#****************************************************************************************#
#* Main                                                                                 *#
#****************************************************************************************#

#* gets input parameters
my ($input_file, $output_prefix, $ref_location, $sex, $run, $print, $write, $help);
GetOptions ("input|i=s"  => \$input_file,
            "output|o=s" => \$output_prefix,
            "sex|s=s"  => \$sex,
            "ref|g=s" =>\$ref_location,
            "run|r:i" => \$run, # optional number of threads
            "print|p" => \$print,
            "write|w" => \$write,
            "help|h"     => \$help
		   ) or die($help_message);

# check necessary files exist
if (defined($help))
{
   print $help_message;
}
elsif (!defined($input_file))
{
   print "Input file not specified\n\n";
   print $help_message;
}
else
{
   # impute here
   my %num_jobs;
   my @chr_names;

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

   my $impute_option;
   if (defined($write))
   {
      $impute_option = "write";
   }
   elsif (defined($run))
   {
      $impute_option = "run";
   }
   else
   {
      $impute_option = "print";
   }

   print "Inputs:\n";
   print "\t Input file:     $input_file\n";
   print "\t Output prefix:  $output_prefix\n";
   print "\t Impute option:  $impute_option\n";
   print "\t Sex:            $twentythree::sex_table{$sex}\n";
   print "\t Reference:      $ref_location\n\n";

   $sex = twentythree::format_convert($input_file, $output_prefix, $sex);

   if (!defined($ref_location))
   {
      $ref_location = "./";
   }

   print "Getting chromosome lengths: ";
   # Get list of files to process
   for (my $i = 1; $i<=22; $i++)
   {
      push(@chr_names, $i);
      print "$i ";

      # Also calculate number of jobs
      my $legend_name = "$ref_location$twentythree::legend_prefix$i$twentythree::legend_suffix";
      $num_jobs{$i} = chrom_jobs("$legend_name");
   }

   if ($twentythree::sex_table{$sex} eq "female")
   {
      push(@chr_names, "X");
      print "X\n";

      my $legend_name = $ref_location . $twentythree::legend_prefix . "X_nonPAR" . $twentythree::legend_suffix;
      $num_jobs{"X"} = chrom_jobs("$legend_name");

      # Create sample_g file
      twentythree::print_sample($sex);
   }
   else
   {
      push(@chr_names, "Y");
      print "Y\n";

      my $legend_name = $ref_location . $twentythree::legend_prefix . "Y" . $twentythree::legend_suffix;
      $num_jobs{"Y"} = chrom_jobs("$legend_name");
   }

   # Now get a list of impute2 commands
   my (@impute_commands, @cat_commands, @cat_hap_commands);
   foreach my $chr_name (@chr_names)
   {

      my $cat_command = "cat ";
      my $cat_hap_command = "cat ";

      for (my $i = 1; $i<= $num_jobs{$chr_name}; $i++)
      {
         my $impute_command;
         if ($chr_name eq "X")
         {
            my $ref_chr_name = $chr_name . "_nonPAR"; # used for map, haps and legend
            $impute_command = "impute2 -chrX -m $ref_location$twentythree::map_prefix" . $ref_chr_name . "$twentythree::map_suffix -h $ref_location$twentythree::haplotype_prefix" . $ref_chr_name . "$twentythree::haplotype_suffix -l $ref_location$twentythree::legend_prefix" . $ref_chr_name . "$twentythree::legend_suffix -g $output_prefix.chr$chr_name.gen -sample_g $twentythree::sample_g_name -int " . ($i-1)*5 . "e6 " . $i*5 . "e6 -Ne $twentythree::eff_pop -o $twentythree::impute2_prefix$chr_name.$i -phase -allow_large_regions";
         }
         else
         {
            $impute_command = "impute2 -m $ref_location$twentythree::map_prefix" . $chr_name . "$twentythree::map_suffix -h $ref_location$twentythree::haplotype_prefix" . $chr_name . "$twentythree::haplotype_suffix -l $ref_location$twentythree::legend_prefix" . $chr_name . "$twentythree::legend_suffix -g $output_prefix.chr$chr_name.gen -int " . ($i-1)*5 . "e6 " . $i*5 . "e6 -Ne $twentythree::eff_pop -o $twentythree::impute2_prefix$chr_name.$i -phase -allow_large_regions";

         }

         push(@impute_commands, $impute_command);

         $cat_command .= "$twentythree::impute2_prefix$chr_name.$i ";
         $cat_hap_command .= "$twentythree::impute2_prefix$chr_name.$i.haps ";
      }

      $cat_command .= "> $output_prefix.$chr_name.gen";
      $cat_hap_command .= "> $output_prefix.$chr_name.phased.haps";
      push(@cat_commands, $cat_command);
      push(@cat_hap_commands, $cat_hap_command);
   }

   my $jobs = scalar(@impute_commands);
   print("$jobs impute2 job commands created\n");

   # Output or print commands in requested format
   if ($run && $run > 1)
   {
      if ($run > 1)
      {
         my $jobs_per_thread = ceil($jobs/$run);
         print("Running imputation with $run threads -- $jobs_per_thread jobs per thread\n\n");
         twentythree::run_impute2(\@impute_commands, $run);
      }
      else
      {
         print("Running imputation with a single thread -- $jobs jobs\n\n");
         twentythree::run_impute2(\@impute_commands, 1);
      }

      print("\nWriting final output\n");
      run_cat(\@cat_commands, \@cat_hap_commands);
   }
   elsif($write)
   {
      print("Writing jobs to shell scripts\n");
      foreach my $chr_name (@chr_names)
      {
         my $shell_file = "$output_prefix.$twentythree::shell_prefix.$chr_name.$twentythree::shell_suffix";
         open (COMMAND, ">$shell_file") || die ("FATAL: Could not write to $shell_file\n");

         print COMMAND "#!/usr/bin/sh\n\n";
         for (my $i = 1; $i<= $num_jobs{$chr_name}; $i++)
         {
            my $impute_command = shift(@impute_commands);
            print COMMAND "$impute_command\n";
         }
         close COMMAND;
         chmod 0755, $shell_file;
      }

      my $cat_shell_file = "$output_prefix.$twentythree::cat_shell_file_name";
      open (CATSH, ">$cat_shell_file") || die ("FATAL: Could not write to $cat_shell_file");

      print CATSH "#!/usr/bin/sh\n\n";
      foreach my $cat_command (@cat_commands)
      {
         print CATSH "$cat_command\n";
      }
      foreach my $cat_hap_command (@cat_hap_commands)
      {
         print CATSH "$cat_hap_command\n";
      }

      close CATSH;
      chmod 0755, $cat_shell_file;
   }
   else
   {
      foreach my $impute_command (@impute_commands)
      {
         print "$impute_command\n";
      }
      print "\nRun once all analysis has finished:\n";
      foreach my $cat_command (@cat_commands)
      {
         print "$cat_command\n";
      }
      foreach my $cat_hap_command (@cat_hap_commands)
      {
         print "$cat_hap_command\n";
      }
   }
}

print("\nDone.\n");

exit(0);
