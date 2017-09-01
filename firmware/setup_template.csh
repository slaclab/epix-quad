
# Setup the license files
if ( $?LM_LICENSE_FILE ) then
    setenv LM_LICENSE_FILE "2100@rdlic1:1717@rdlic1:2100@rdlic2:1717@rdlic2:2100@rdlic3:1717@rdlic3":${LM_LICENSE_FILE}

else
    setenv LM_LICENSE_FILE "2100@rdlic1:1717@rdlic1:2100@rdlic2:1717@rdlic2:2100@rdlic3:1717@rdlic3"
endif

# Setup the Xilinx software 
set KERNAL_TYPE = `uname -m`
if ( $KERNAL_TYPE == "x86_64" ) then
	printf  "Using 64-bit Xilinx\n"
#	source /afs/slac/g/reseng/xilinx/ise_14.7/ISE_DS/settings64.csh
    source /afs/slac/g/reseng/xilinx/vivado_2016.4/Vivado/2016.4/settings64.csh
else
	printf  "Firmware can only be compiled on 64-bit OS\n"
endif

# Setup the VCS software
source /afs/slac.stanford.edu/g/reseng/synopsys/vcs-mx/M-2017.03-1/settings.csh
#source /afs/slac.stanford.edu/g/reseng/synopsys/vcs-mx/L-2016.06/settings.csh
#source /afs/slac.stanford.edu/g/reseng/synopsys/ns/G-2012.06/settings.csh
#source /afs/slac.stanford.edu/g/reseng/synopsys/CosmosScope/D-2010.03/settings.csh

# Create an output build directory in the /u1 hardware mount
set USER_DIR       = "/u1/$USER"
set USER_BUILD_DIR = "/u1/$USER/build"
set SOFT_LINK      = "build"

if(! -d $USER_DIR) then
	printf "Making %s directory\n" $USER_DIR	
	mkdir $USER_DIR
endif

if(! -d $USER_BUILD_DIR ) then
	printf "Making %s directory\n" $USER_BUILD_DIR 
	mkdir $USER_BUILD_DIR 
endif

if(! -d $SOFT_LINK ) then
	printf "Making %s soft-link\n" $SOFT_LINK
	ln -s $USER_BUILD_DIR build 
endif
