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
# JTAG_uploader.tcl - Version 6.00 - 4 February 2010
# This is a tcl file that will allow the user to upload blockram data to jtag_loader_6
#
# Kris Chaplin - Xilinx UK chaplin@xilinx.com
#


puts "JTAG UpLoader for Jtag Loader 6 - Kris Chaplin November 2009"

## Check for the right number of arguments

if { $argc != 2 & $argc != 3 & $argc != 4 } {
 puts "Usage: xtclsh jtag_uploader.tcl <board> <hexfile.hex> \[picoblaze target\] \[reset value\]"
 exit
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

## Sanity check reset value number input

if { $argc eq 4 } {
if [string is integer [lindex $argv 3]] {
set reset_value [lindex $argv 3]
} else {
puts "Error: Invalid integer '[lindex $argv 3]' for reset value"
exit
} 
} else {
set reset_value 255
}

set board_file "[lindex $argv 0].jtag6"
set hex_file "[lindex $argv 1]"

## Check if the board file exists

if [expr [file isfile $board_file] eq 0] {
 puts "ERROR: Could not find board file for [lindex $argv 0]  ($board_file)."
 puts "Please check the documentation on how to make this file"
 exit
} 

## Check if the hex file exists, and if not if it exists 
## when adding .hex to the extension

if [expr [file isfile $hex_file] eq 0] {
 if [expr [file isfile "$hex_file.hex"] eq 0] {
  puts "ERROR: Could not find hex file $hex_file"
  puts "Please check and try again"
  exit
 } else  {
  set hex_file "[lindex $argv 1].hex"
 }
}

###### Hex file and board file exist and other values are integers

puts "Board selected    : $board_file"
puts "Hex File selected : $hex_file"
puts "PicoBlaze target  : $picoblaze_target "
puts "Reset value       : $reset_value "

## Executing the file specified for the selected board
## Would make Steve Gibson cringe.. security issue only if 
## public access to script arguments running on a remote machine
## which is unlikely

source $board_file

## Jtag_loader.tcl contains the main functions to control the JTAG_LOADER_6 peripheral on a board

source jtag_loader.tcl

puts "Resetting all picoblaze"
## Register 0 is the reset register for all brams in the loader
write_register 0 $io $reset_value

puts "Writing contents of $hex_file into bram"
read_from_file 1024 $picoblaze_target $hex_file
puts "Done"

puts "Releasing reset for all picoblaze"
write_register 0 $io 0
write_register 0 $io 0
 

puts $io "exit";
flush $io;
close $io;


