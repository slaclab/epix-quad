# Define target output
target: prom

# Define Firmware Version Number
export PRJ_VERSION = 0xEA050011

# Use the PGPv4 6G core
export INCLUDE_PGP4_6G = 1

# Define release
ifndef RELEASE
export RELEASE = all
endif

# Define the Microblaze source path
export VITIS_SRC_PATH = $(PROJ_DIR)/../../common/EpixQuadCommon/src

# Define if you want to build the user Microblaze core
export BUILD_MB_CORE = 1

# Define if you want to build the DDR MIG core
export BUILD_MIG_CORE = 0

# Define if this is FSBL PROM address
export PROM_FSBL = 1

# Define if you want to remove unused source code
export REMOVE_UNUSED_CODE = 0

# Define target part
export PRJ_PART = XCKU035-SFVA784-1-C

# Use top level makefile
include ../../submodules/ruckus/system_vivado.mk



#-------------------------------------------------------------------------------
#-- Revision History:
#-- 07/30/2018 (0xEA050000): First revision
#-- 07/30/2018 (0xEA050001): fit whole image in the output stream FIFO
#-- 10/17/2018 (0xEA050002): added monitoring data readout and streams
#-------------------------------------------------------------------------------
