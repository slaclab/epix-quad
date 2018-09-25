export GIT_BYPASS = 1

# Define Firmware Version Number
export PRJ_VERSION = 0xEA040000

# Define the Microblaze source path
export SDK_SRC_PATH = $(PROJ_DIR)/../../common/EpixQuadCommmon/src/

# Define if you want to build the user Microblaze core
export BUILD_MB_CORE = 1

# Define if you want to build the DDR MIG core
export BUILD_MIG_CORE = 0

# Define if this is FSBL PROM address
export PROM_FSBL = 1

# Define if you want to remove unused source code
export REMOVE_UNUSED_CODE = 0

# Define target output
target: prom

# Define target part
export PRJ_PART = XCKU035-SFVA784-1-C

# Use top level makefile
include ../../submodules/ruckus/system_vivado.mk



#-------------------------------------------------------------------------------
#-- Revision History:
#-- 07/30/2018 (0xEA040000): First revision
#-------------------------------------------------------------------------------
