##cd ~philiph/glast/lcls/epix/
##source setup_env.csh
##setenv EXTERNAL_LIBS /afs/slac.stanford.edu/g/reseng/vol4/lcls_daq_new
#~philiph/glast/lcls/epix/bin/epixRealMon -p ePixPartition -c 48 -r 178 -C 1 -R 1 &
killall ami
killall epixRealMon
killall online_ami
~philiph/glast/lcls/epix/bin/epixRealMon -p ePixPartition -c 192 -r 178 -C 2 -R 2 &
$EXTERNAL_LIBS//ami/bin/x86_64-linux-opt/ami -R -p ePixPartition -i lo -s 239.255.38.5 &
$EXTERNAL_LIBS/ami/bin/x86_64-linux-opt/online_ami -I lo -i lo -s 239.255.38.5 &

