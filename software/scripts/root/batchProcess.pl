use warnings;
use strict;

my $baseDir = "data_rdpc84/20140129/";

#for (my $acq = 40; $acq <= 200; $acq += 10) {
for (my $acq = 200; $acq <= 200; $acq += 10) {
   for (my $pulse = 200; $pulse <= 1000; $pulse += 200) {
      my $darkFile  = sprintf("%scardS1.acq%03d.dark",$baseDir,$acq);
      my $pulseFile = sprintf("%scardS1.acq%03d.pulse%d",$baseDir,$acq,$pulse);
      my $rootFile  = sprintf("%scardS1.acq%03d.pulse%d.root",$baseDir,$acq,$pulse);

      print "Processing $pulseFile...\n";

      open(ROOT, "| root -b -l");
      print ROOT ".L scripts/root/ProcessData.C+\n";
      print ROOT "ProcessData(\"$pulseFile\",\"$darkFile\",false,\"$rootFile\")\n";
      print ROOT ".q\n";
#      print "ProcessData(\"$darkFile\",\"$pulseFile\",false,\"$rootFile\")\n";
      close(ROOT);

      print "...done!\n";
   }
}
