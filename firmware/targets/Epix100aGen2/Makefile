export GIT_BYPASS = 1

# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A200TSBG484-3

# List of build core directories.
#export MODULE_DIRS = $(PROJ_DIR)/../../common/StdLib  \
#                     $(PROJ_DIR)/../../common/StdLib/obsolete  \
#                     $(PROJ_DIR)/../../common/AxiAd9249Core \
#                     $(PROJ_DIR)/../../common/AxiMicronN25QCore  \
#                     $(PROJ_DIR)/../../common/pgp2b_core/gtp7 \
#                     $(PROJ_DIR)/../../common/pgp2b_core/core \
#                     $(PROJ_DIR)/../../common/MgtLib/gtp7  \
#                     $(PROJ_DIR)/../../common/EpixCommonGen2  \
#                     $(PROJ_DIR)/../../common/MicroblazeBasicCore \
#                     $(PROJ_DIR)

export RUCKUS_DIR = $(abspath $(PWD)/../../modules/ruckus)
export MODULES = $(abspath $(PWD)/../../modules)

export PRJ_VERSION = 0x00000001

# Use top level makefile
include $(RUCKUS_DIR)/system_vivado.mk


export SDK_SRC_PATH = $(PROJ_DIR)/../../common/EpixCommonGen2/src/ePix100a

# Max number of smart explorer runs
export SMART_MAX_RUNS = 10

# Use top level makefile
#include ../../common/StdLib/build/system_vivado_v1.mk
