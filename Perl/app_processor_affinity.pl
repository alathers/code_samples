#!/usr/bin/perl

###################
#
#  Adam Lathers
#  alathers@gmail.com
#
#    Problem statement: If one processor is too busy, it can starve real time processes
#                     Most vendors tend to find 1 processor for handling network interrupts
#                     This causes process starvation when the app start doesn't properly detect this  
#
#    Tool used for adjusting processor affinity for an in house real time application
#
#
#
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#
#
#######################


## Original comments below:


# Adam Lathers, technical operations
# 9/2008
# SOMEAPP processes default to 1-n, skipping 0 to avoid collision with processor
# that should be handling eth software interrupts.  This is unfortunately
# a non-deterministic behavior on some hardware, so we need to make sure that
# we move all SOMEAPP processes if they collide with the processor handling greatest
# load of software interrupts.


#find out how many processors there are
my $numprocs = '';
$_= `grep process /proc/cpuinfo  | tail -n 1`;
$_=~m/(\d*)\w*$/;
$numprocs=$1;

my @someappprocs = `pgrep -u someuser someapp`;
chomp(@someappprocs);
my $numsomeapps = $#someappprocs + 1;
print "This host has $numprocs cores total, it should have ". $numprocs-- . " SOMEAPP processes or fewer.\n";
print "\tPresently I see " . $numsomeapps . "\n\n\n";


#assumption is that proc 0 is generally used for eth interrupts, not always true.
my $affin = 0;
my @occupied;
foreach $h (0 .. $numprocs) { $occupied[$h] = 0;} 
my $needsmoving= undef;

#find out who's doing software interrupts for eth
    ## find out who's doing the most!

my @irqs = `egrep eth  /proc/interrupts`;
#make sure it's safe to split on white space.
foreach $h ( 0 .. $#irqs) {
        $irqs[$h]=~s/^\s+//g;
        $irqs[$h]=~s/\s*$//g;
}

my @temp = split /\s+/,$irqs[0];
#toss unneeded values
pop @temp;
pop @temp;
shift @temp;
        
my $curmax=0;
$i=0;
foreach $item (@temp) {
    
    if ( ($item > 0) && ($item > $curmax)  ) { 
        $affin=$i;
        $curmax=$item;
    }
    $i++;
}


print "Processor affinity for network software interrupts is: $affin" . "\n\n";
$occupied[$affin] = 1;


#find out what processor the SOMEAPP procs are on.
foreach $h (0 .. $#someappprocs) {
    chomp($someappprocs[$h][0] = `taskset -pc $someappprocs[$h]`);
    $_=$someappprocs[$h][0];
    $_=~m/(\d*)\w*$/;
    chomp($someappprocs[$h][1] = $1);
    
    print "affin: for process $someappprocs[$h] is : $someappprocs[$h][1] \n";
    if ($someappprocs[$h][1] == $affin) { 
        print "$someappprocs[$h] needs to move.  Proc ID $someappprocs[$h], and system interrupts are both on $affin\n";
        $needsmoving = $someappprocs[$h];
    }
    $occupied[$someappprocs[$h][1]]=1;

}
if (!$needsmoving) { 
   print "No procs need to move, exiting gracefully...\n\n";
   exit;
}
else {

for $h (0 .. $#occupied) { 
   print "h is $h and value is $occupied[$h]\n";
   if ($occupied[$h] == 0 ) {
      my $movecommand="taskset -pc $h $needsmoving";
      print "looks like $h is unoccupied.  trying to move $needsmoving here\n
      executing: $movecommand\n\n";
      `$movecommand`;
      exit
   }
}
}
exit
