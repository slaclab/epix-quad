##
###########################################################################################
## Copyright © 2010, Xilinx, Inc.
## This file contains confidential and proprietary information of Xilinx, Inc. and is
## protected under U.S. and international copyright and other intellectual property laws.
###########################################################################################
##
## Disclaimer:
## This disclaimer is not a license and does not grant any rights to the materials
## distributed herewith. Except as otherwise provided in a valid license issued to
## you by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE
## MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY
## DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY,
## INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT,
## OR FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable
## (whether in contract or tort, including negligence, or under any other theory
## of liability) for any loss or damage of any kind or nature related to, arising
## under or in connection with these materials, including for any direct, or any
## indirect, special, incidental, or consequential loss or damage (including loss
## of data, profits, goodwill, or any type of loss or damage suffered as a result
## of any action brought by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-safe, or for use in any
## application requiring fail-safe performance, such as life-support or safety
## devices or systems, Class III medical devices, nuclear facilities, applications
## related to the deployment of airbags, or any other applications that could lead
## to death, personal injury, or severe property or environmental damage
## (individually and collectively, "Critical Applications"). Customer assumes the
## sole risk and liability of any use of Xilinx products in Critical Applications,
## subject only to applicable laws and regulations governing limitations on product
## liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
##
###########################################################################################
##
# JTAG_loader.tcl - Version 6.00 - 4 February 2010
# This is a TCL script to interface to JTAG Loader 6 hardware.  Please read the documentation
# for more information
#
# Kris Chaplin - Xilinx UK chaplin@xilinx.com
#


set max_num_picoblaze 8
set max_addr_width 16
set max_instruction_dwidth 16
set max_bram_awidth 16 

source jtag_loader_processes.tcl
#source ml403.jtag6

puts "JTAG Loader 6 version 6.00 by Kris Chaplin, Xilinx UK\n";
puts "Launching iMPACT in batch mode to interface to the board\n";

puts "***** User has set BSCAN chain to $jtag_devices_upstream devices upstream of IR length $irlength_upstream"
puts "***** and $jtag_devices_downstream devices downstream of IR length $irlength_downstream"
puts "***** Using usercode $usercode for the fpga"

# open impact in batch mode
set io [open "|impact -batch" r+]
fconfigure $io -blocking 0

# wait for initial splash screen to complete, and a command prompt to return
wait_chevron $io;

puts "***** Setting mode to bscan";
puts $io "setmode -bscan";
wait_chevron $io;

puts "***** Auto detecting cable";
puts $io "setcable -p auto";
wait_chevron $io;

puts "***** Start bsdebug";
puts $io "bsdebug -start";
wait_chevron $io;

puts "***** Reset debug";
puts $io "bsdebug -reset";
wait_chevron $io;

puts "***** Set IR to User register $usercode"

## Calculate instruction bitstream to set upstream and downstream devices to bypass (all 1's) and target FPGA to usercode
 set tdi_data "" 
 for {set i 0} {$i < $irlength_upstream} {incr i 1} {
 append tdi_data "1"
 }

 append tdi_data $usercode

 for {set i 0} {$i < $irlength_downstream} {incr i 1} {
 append tdi_data "1"
 }

###
# puts "*** *** *** TDI data $tdi_data";
puts $io "bsdebug -scanir $tdi_data"
set tdo_data [capture_tdo_data $io 1] ;
# puts "***** TDO Data = $tdo_data";


## Calculate worst case scan chain to clear all bits apart from control reg CE
set tmp1 $jtag_devices_upstream
set tmp2 [ expr $max_num_picoblaze + 1 + $max_addr_width + $max_instruction_dwidth + $jtag_devices_downstream] 

set tdi_data ""
for {set i 0} {$i < $tmp1} {incr i 1} {
	append tdi_data "0"
}
 
append tdi_data "1"

for {set i 0} {$i < $tmp2} {incr i 1} {
	append tdi_data "0"
}

# puts "***** Set Bscan Data register to set control reg 0 to read"
puts $io "bsdebug -scandr $tdi_data"
set tdo_data [capture_tdo_data $io 1] ;
# puts "***** TDO Data = $tdo_data";


# puts "***** Read control reg 0 $tdi_data"
puts $io "bsdebug -scandr $tdi_data"
set tdo_data [capture_tdo_data $io 1] ;
# puts "***** TDO Data = $tdo_data";

set status_register [ string range $tdo_data [ expr [string length $tdi_data] -8 - $jtag_devices_downstream ] [ expr [string length $tdi_data] -1 - $jtag_devices_downstream ] ]
puts "Status register = $status_register";

set num_picoblaze 1
if { [string index $status_register 7] eq "1" } { set num_picoblaze [ expr $num_picoblaze + 4 ] } 
if { [string index $status_register 6] eq "1" } { set num_picoblaze [ expr $num_picoblaze + 2 ] } 
if { [string index $status_register 5] eq "1" } { set num_picoblaze [ expr $num_picoblaze + 1 ] } 

set picoblaze_data_width 1
if { [string index $status_register 4] eq "1" } { set picoblaze_data_width [ expr $picoblaze_data_width + 16 ] } 
if { [string index $status_register 3] eq "1" } { set picoblaze_data_width [ expr $picoblaze_data_width + 8  ] } 
if { [string index $status_register 2] eq "1" } { set picoblaze_data_width [ expr $picoblaze_data_width + 4  ] } 
if { [string index $status_register 1] eq "1" } { set picoblaze_data_width [ expr $picoblaze_data_width + 2  ] } 
if { [string index $status_register 0] eq "1" } { set picoblaze_data_width [ expr $picoblaze_data_width + 1  ] } 

set max_bram_awidth [ read_register 15 $io ]

puts "Number of PicoBlazes in system = $num_picoblaze";
puts "Maximum Bram Data Width = $picoblaze_data_width";
puts "Maximum Bram address Width = $max_bram_awidth";

for {set i 1 } {$i <= $num_picoblaze} {incr i 1} {
	set tmp [ read_register $i $io ]
	puts "PicoBlaze $i: Reset : [ expr ($tmp & 128) eq 128 ] Blockram Address Width [ expr $tmp & 31 ]"
}

