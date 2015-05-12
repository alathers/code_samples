#!/usr/bin/perl -w
#
# Quick hack to help a friend in marketing operations
#
#  Poorly structured data has lead to issues with importing into SaaS tool.  Do some quick clean up to make this uniform so he can import it more reliability
#
#
#



use strict;
use warnings;


if (($#ARGV+1) != 1) {
        print "Please provide an output filename\n\n\t\t usage: $0 filename\n\n
        \n\n  \t\tPLEASE MAKE SURE THERE ARE NO OTHER FILES PRESENT EXCEPT: Exported leads files\n\n";
        exit 1;
}

my $datestamp = `date +%Y%m%d`;

my $script = $0;
#my $dir = $ARGV[0];
my $dir = `pwd`;
my $outfile = $ARGV[0];

#fix this later to strip out the filename of the script.
my @files = `ls -1 $dir`;
#pop @files;

# Wrappers for releveant data
my $header = "Record Information:";
my $footer = "To incorporate this lead into Salesforce you can key in the data above.";
####

# switches to identify when to expecting "useful" data
my $headtest = 0;
my $foottest = 0;

#Iterators
my $h;
my $i;

# current file
my $curline;

# What heading to print to outfile file.  Also used to bin the various data for standardized output format
my %headings;

# loop values to parse lines
my $key = '';
my $value = '';

my $processedfiles = "ProcessedFiles.txt";
open PROCESSLOG, ">> $processedfiles" or die "Can't open log file:   $!\n\n";

foreach $h (0 .. $#files) {
    $headtest = $foottest = 0;

    open INPUT, "$files[$h]" or die "can't open file $files[$h]:$!\n\n";

    while ($curline = <INPUT>) {
        if ($curline =~ $header) {
            $headtest = 1;
        }
        elsif ($curline =~ $footer) {
            $foottest = 1;
        }
        ## skips lines that encapsulate the data of interest.  Use as start/stop points
        ## Also skip lines that are empty
        elsif (($headtest > 0) && ($foottest == 0) && (length $curline > 2) && ($curline !~ /^\s*$/) ) {
            #bin them up.  hash of arrays
            ($key,$value) = split('=', &trim($curline), 2);
            $headings{&trim($key)}[$h] = &trim($value);
        }

    }
    close INPUT;
    print PROCESSLOG "$files[$h] was row $h\n";
}
    print PROCESSLOG "\n\n finished processing $datestamp \n\n";
    close PROCESSLOG;


open (OUTFILE, "> ./$outfile") or die "Can't open output file:$!\n\n";
# Print the headings
foreach (sort { $headings{$a} cmp $headings{$b} } keys %headings) {
    print OUTFILE $_ . "\t";
}
print OUTFILE "\n";


foreach $h (0 .. $#files+1) {
    foreach $i (sort { $headings{$a} cmp $headings{$b} } keys %headings){
        if ($headings{$i}[$h]) {
        print OUTFILE $headings{$i}[$h] . "\t" ;
        }
        else {
        print OUTFILE " \t";
        }
    }
    print OUTFILE "\n";
}
close OUTFILE;


# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+// if defined $string;
        $string =~ s/\s+$// if defined $string;
        return $string;
}

