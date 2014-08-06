#!/bin/tcsh

source /afs/slac/g/reseng/xilinx/ise_14.7/ISE_DS/settings64.csh

cd ../loader/
xtclsh jtag_uploader.tcl ../code/EpixDigBoard ../code/EpixStartupCode.hex
