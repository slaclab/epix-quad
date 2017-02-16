
# Define target output
target: prom

# Define target part
export PRJ_PART = XC7K325TFFG900-2

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../common/StdLib  \
                     $(PROJ_DIR)/../../common/StdLib/obsolete  \
                     $(PROJ_DIR)/../../common/AxiAd9249Core \
                     $(PROJ_DIR)/../../common/AxiMicronN25QCore  \
                     $(PROJ_DIR)/../../common/pgp2b_core/gtx7 \
                     $(PROJ_DIR)/../../common/pgp2b_core/core \
                     $(PROJ_DIR)/../../common/MgtLib/gtx7  \
                     $(PROJ_DIR)/../../common/EpixCommonGen2  \
                     $(PROJ_DIR)/../../common/MicroblazeBasicCore \
                     $(PROJ_DIR)

# Use top level makefile
include ../../common/StdLib/build/system_vivado_v1.mk
