23andme-impute
==============

Scripts and advice to run IMPUTE2 on 23 and me raw data

Usage:

   impute_genome.pl -i input_file [-o output_prefix -s <sex>]
[impute_options]

Imputes whole genome SNPs from the raw data of ~450 000 SNPs typed by
23andme, and also phases the typed sites.
This is a computationally heavy task, and so running output commands in
parallel is recommended.

   input_options
   -i, --input    The 'raw data' file from 23 and me, which has four tab
                  separated columns: rsid, chromosome, position, genotype
   -o, --output   The prefix for the output .gen files (default is the
                  input name)
   -s, --sex      The sex of the subject, either male (m) or female (f). If
                  omitted a guess will be made based on presence of Y
                  chromosome sites

   impute_options:
   -r, --run [threads]
                  Directly execute the imputation, but note this requires
                  a lot of memory and CPU time. Optionally supply an
                  integer number of jobs to simultaneously
                  execute. This should be <= number of cores, but this is
                  not checked
   -p, --print    Print the imputation commands to STDOUT rather than
                  executing them - default behaviour
   -w, --write    Write to commands to shell scripts, for execution later
                  by a job scheduling system

   other
   -h, --help     Displays this help message

For example:

   ./impute_genome.pl -i 23andme_rawdata.txt -o imputed -s m -r 4

Would impute the genome from 23andme_rawdata.txt, which is a male subject (homozygous X chromosome, has
Y chromosome data) and then runs the analysis in parallel over four separate threads
