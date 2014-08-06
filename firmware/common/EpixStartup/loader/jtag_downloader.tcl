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
# JTAG_downloader.tcl - Version 6.00 - 4 February 2010
# This is a tcl script that will allow the user to download blockram data from jtag_loader_6
#
# Kris Chaplin - Xilinx UK chaplin@xilinx.com
#

puts "JTAG DownLoader for Jtag Loader 6 - Kris Chaplin January 2010"
puts "Version 6.00"

## Check for the right number of arguments

if { $argc != 3 } {
 if { $argc != 2} {
 puts "Usage: xtclsh jtag_downloader.tcl <board> <hexfile.hex> \[picoblaze target\] "
 exit
 }
} 

## Sanity check picoblaze target number input

if { $argc eq 2 } {
 set picoblaze_target 0
} else {
 if [string is integer [lindex $argv 2]] {
  set picoblaze_target [lindex $argv 2]
 } else {
  puts "Error: Invalid integer '[lindex $argv 2]' for picoblaze   target number"
  exit
 }
}

set board_file "[lindex $argv 0].jtag6"
set hex_file "[lindex $argv 1]"

## Check if the board file exists

if [expr [file isfile $board_file] eq 0] {
 puts "ERROR: Could not find board file for [lindex $argv 0]  ($board_file)."
 puts "Please check the documentation on how to make this file"
 exit
} 


###### Hex file and board file exist and other values are integers

puts "Board selected    : $board_file"
puts "Hex File selected : $hex_file"
puts "PicoBlaze target  : $picoblaze_target "

## Executing the file specified for the selected board
## Would make Steve Gibson cringe.. security issue only if 
## public access to script arguments running on a remote machine
## which is unlikely

source $board_file

## Jtag_loader.tcl contains the main functions to control the JTAG_LOADER_6 peripheral on a board

source jtag_loader.tcl

#puts "Resetting all picoblaze"
## Register 0 is the reset register for all brams in the loader
# write_register 0 $io $reset_value

puts "Reading contents of PicoBlaze $picoblaze_target into file $hex_file"
write_to_file 1024 $picoblaze_target $hex_file
puts "Done"

puts $io "exit";
flush $io;
close $io;


