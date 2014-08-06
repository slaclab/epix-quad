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
# JTAG_loader_processes.tcl - Version 6.00 - 4 February 2010
# This is a support file of libraries for JTAG loader 6
#
# Kris Chaplin - Xilinx UK chaplin@xilinx.com
#

# wait_chevrom - waits for the command '>' chevron indicator in the input stream.  
# Impact batch mode outputs a chevron when ready for the next command

proc wait_chevron { fileptr } {
	flush $fileptr;
	set line ""
	while { [ regexp {>} $line trash ] < 1 } {
	
		while { [ gets $fileptr line ] > 0 } {
			puts $line ;
		}
		set line [read $fileptr];
	}
}

# Capture_tdo_data expects a command to be in progress in impact, and will capture 
# the resultant reported TDO data out of the tool

proc capture_tdo_data { fileptr display } {
	# puts "*** *** *** capture_tdo_data";
	flush $fileptr;
	set line ""
	while { [ regexp {TDO\sCapture\sData:\s*(\d*)} $line trash tdo_data] < 1 } {
		if { [ gets $fileptr line ] > 0 } {
			if { $display > 0 } {
			puts $line ;
			}
		}
		# set line [read $fileptr];
	}	
return $tdo_data;
}

# num_to_bin converts an integer to a string of binary data (in reverse order)

proc num_to_bin { num size } {
	set bin ""
	set power 1
	for {set i 0} {$i < $size } {incr i 1} {
		if { ($power & $num ) > 0 } {
			append bin "1";
		} else {
			append bin "0";
		}
	set power [ expr $power * 2 ]
	}
return $bin;	
}

# bin_to_num inputs an ascii formatted binary stream, and converts it to decimal
proc bin_to_num { bin } {
	set num 0
	set power 1

	for {set i 0} {$i < [string length $bin] } {incr i 1} {

		if {  [ string index $bin $i ] eq "1" } {
		incr num $power
		} 
	set power [ expr $power * 2 ]
	}
	return $num
}

# read_register reads from the control registers in the JTAG loader and returns an integer
proc read_register { reg fileptr } {

	global jtag_devices_upstream
	global jtag_devices_downstream
	global num_picoblaze
	global max_bram_awidth
	global picoblaze_data_width
	
	set regstring [num_to_bin $reg 4]
	
	set tdi_data ""
	# puts " *** *** *** read_register $regstring"

	# shift in enough data to get address to 1111, control_ce=1

	for {set i 0} {$i < $jtag_devices_upstream} {incr i 1} {
	append tdi_data "0";
	}

	append tdi_data "1"
	
	for {set i 0} {$i < $num_picoblaze} {incr i 1} {
	append tdi_data "0";
	}

	append tdi_data "0";
	append tdi_data $regstring;

	for {set i 0} {$i < [ expr $max_bram_awidth - [string length $regstring] + $picoblaze_data_width ] } {incr i 1} {
	append tdi_data "0";
	}
	
	for {set i 0} {$i < $jtag_devices_downstream} {incr i 1} {
	append tdi_data "0";
	}

	#puts "***** Tdi data = $tdi_data";
	#puts "***** Set DR to CS for register 0"
	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
	#puts "***** TDO Data = $tdo_data";

	#puts "***** Set DR to CS for register 0"
	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
	#puts "***** TDO Data = $tdo_data";

	set status_register [ string range $tdo_data [ expr [string length $tdi_data] -8 - $jtag_devices_downstream] [ expr [string length $tdi_data] -1 - $jtag_devices_downstream ]  ]
	#puts " *** *** *** status register $status_register"
	set regdata 1

	if { [string index $status_register 7] eq "1" } { set regdata [ expr $regdata + 128] } 
	if { [string index $status_register 6] eq "1" } { set regdata [ expr $regdata + 64 ] } 
	if { [string index $status_register 5] eq "1" } { set regdata [ expr $regdata + 32 ] } 
	if { [string index $status_register 4] eq "1" } { set regdata [ expr $regdata + 16 ] } 
	if { [string index $status_register 3] eq "1" } { set regdata [ expr $regdata + 8  ] } 
	if { [string index $status_register 2] eq "1" } { set regdata [ expr $regdata + 4  ] } 
	if { [string index $status_register 1] eq "1" } { set regdata [ expr $regdata + 2  ] } 
	if { [string index $status_register 0] eq "1" } { set regdata [ expr $regdata + 1  ] } 

	return $regdata
}

# read_memory reads from a bockram memory and returns an integer
proc read_memory { picoblaze reg fileptr } {

	global jtag_devices_upstream
	global jtag_devices_downstream
	global num_picoblaze
	global max_bram_awidth
	global picoblaze_data_width
	
	set regstring [num_to_bin $reg $picoblaze_data_width]
	
	set tdi_data ""
	# puts " *** *** *** read_memory $regstring"

	# shift in enough data to get address to 1111, control_ce=1

	for {set i 0} {$i < $jtag_devices_upstream} {incr i 1} {
	append tdi_data "0";
	}

	append tdi_data "0"
	
	# set the appropriate chipselect
	set chipselect [ expr int(pow(2,$picoblaze)) ]
	append tdi_data [ num_to_bin $chipselect $num_picoblaze ];

	append tdi_data "0";
	append tdi_data $regstring;

	for {set i 0} {$i < [ expr $max_bram_awidth - [string length $regstring] + $picoblaze_data_width ] } {incr i 1} {
	append tdi_data "0";
	}
	
	for {set i 0} {$i < $jtag_devices_downstream} {incr i 1} {
	append tdi_data "0";
	}

	# puts "*** *** ***  Tdi data = $tdi_data";
	#puts "***** Set DR to CS for register 0"
	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
	#puts "***** TDO Data = $tdo_data";

	#puts "***** Set DR to CS for register 0"
	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
	#puts "***** TDO Data = $tdo_data";

	set status_register [ string range $tdo_data [ expr [string length $tdi_data] -$picoblaze_data_width - $jtag_devices_downstream] [ expr [string length $tdi_data] -1 - $jtag_devices_downstream ]  ]
	# puts " *** *** *** status register $status_register"
	set regdata 0
	return [ bin_to_num $status_register ]
}

# write_memory writes to a blockram an integer
proc write_memory { picoblaze reg fileptr data } {

	global jtag_devices_upstream
	global jtag_devices_downstream
	global num_picoblaze
	global max_bram_awidth
	global picoblaze_data_width
	
	set regstring [num_to_bin $reg $max_bram_awidth]
	
	set tdi_data ""
	# puts " *** *** *** read_memory $regstring"

	# shift in enough data to get address to 1111, control_ce=1

	for {set i 0} {$i < $jtag_devices_upstream} {incr i 1} {
	append tdi_data "0";
	}

	append tdi_data "0"
	
	# set the appropriate chipselect
	set chipselect [ expr int(pow(2,$picoblaze)) ]
	append tdi_data [ num_to_bin $chipselect $num_picoblaze ];

	append tdi_data "1";
	append tdi_data $regstring;

	set datastring [num_to_bin $data $picoblaze_data_width]
	#puts "*** *** *** datastring = $datastring $data"
	append tdi_data $datastring
	
	#for {set i 0} {$i < [ expr $max_bram_awidth - [string length $regstring] + $picoblaze_data_width ] } {incr i 1} {
	#append tdi_data "0";
	#}
	
	for {set i 0} {$i < $jtag_devices_downstream} {incr i 1} {
	append tdi_data "0";
	}

	#puts "*** *** ***  Tdi data = $tdi_data";
	#puts "***** Set DR to CS for register 0"
	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
	#puts "***** TDO Data = $tdo_data";

	#puts "***** Set DR to CS for register 0"
	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
	#puts "***** TDO Data = $tdo_data";

	set status_register [ string range $tdo_data [ expr [string length $tdi_data] -$picoblaze_data_width - $jtag_devices_downstream] [ expr [string length $tdi_data] -1 - $jtag_devices_downstream ]  ]
	# puts " *** *** *** status register $status_register"
	set regdata 0
	return [ bin_to_num $status_register ]
}

# write_register writes to the jtag_loader registers an integer
proc write_register { reg fileptr data } {
	global jtag_devices_upstream
	global jtag_devices_downstream
	global num_picoblaze
	global max_bram_awidth
	global picoblaze_data_width
	set regstring [num_to_bin $reg $max_bram_awidth]
	set datastring [num_to_bin $data $picoblaze_data_width]
	set tdi_data ""
	#puts "regstring = $regstring"
	#puts "datastring = $datastring"

	# puts " *** *** *** read_register $regstring"

	# shift in enough data to get address to 1111, control_ce=1

	for {set i 0} {$i < $jtag_devices_upstream} {incr i 1} {
	append tdi_data "0";
	}

	append tdi_data "1"
	
	for {set i 0} {$i < $num_picoblaze} {incr i 1} {
	append tdi_data "0";
	}

	append tdi_data "1";
	append tdi_data $regstring;
	append tdi_data $datastring

	for {set i 0} {$i < $jtag_devices_downstream} {incr i 1} {
	append tdi_data "0";
	}
	# puts " *** *** *** data to write = $tdi_data"

	puts $fileptr "bsdebug -scandr $tdi_data"
	set tdo_data [capture_tdo_data $fileptr 0] ;
}


proc write_to_file { count picoblaze fileptr } {
	global io
	set outputfile [open $fileptr w]
	for {set i 0} {$i < $count} {incr i 1} {
		set tmp [ read_memory $picoblaze $i $io ]
		puts $outputfile [format "%05x" $tmp]
		}
	close $outputfile
	return 0
	}
	
proc read_from_file { count picoblaze fileptr } {
	global io
	set i 0
	set inputfile [open $fileptr r]
	while { [gets $inputfile line] >= 0} {
		# puts "$line"
		set dec_line [expr 0x$line]
		#set data [ num_to_bin $dec_line 20 ]
		write_memory $picoblaze $i $io $dec_line
		#puts "$i $data"
		incr i 1
	}
}