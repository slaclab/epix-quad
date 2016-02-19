source /afs/slac.stanford.edu/u/ec/philiph/glast/lcls/epix_21Jan2015/setup_env.csh
setenv EXTERNAL_LIBS /afs/slac.stanford.edu/g/reseng/vol5/lcls_daq_21Jan2015

~philiph/glast/lcls/epix_21Jan2015/bin/epixRealMon -p ePixPartition -c 384 -r 354 -C 2 -R 2 & 
$EXTERNAL_LIBS/ami/bin/x86_64-linux-opt/ami -R -p ePixPartition -i lo -s 239.255.38.5 & 
#$EXTERNAL_LIBS/ami/bin/x86_64-linux-opt/online_ami -D -I lo -i lo -s 239.255.38.5 &
$EXTERNAL_LIBS/ami/bin/x86_64-linux-opt/online_ami -I lo -i lo -s 239.255.38.5 &

