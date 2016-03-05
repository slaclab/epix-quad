
# Define target output
target: vcs

# Define target part
export PRJ_PART = XC7A200TSBG484-3

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib  \
                     $(PROJ_DIR)/../../modules/StdLib/obsolete \
                     $(PROJ_DIR)/../../modules/MgtLib/gtp7  \
                     $(PROJ_DIR)/../../modules/pgp2b_core/core \
                     $(PROJ_DIR)/../../modules/pgp2b_core/gtp7 \
                     $(PROJ_DIR)/../../modules/EpixCommonGen2  \
                     $(PROJ_DIR)/../../modules/EpixStartupGen2  \
                     $(PROJ_DIR)/../../modules/CpixTixelCommon  \
                     $(PROJ_DIR)/../../modules/Saci/rtl  \
                     $(PROJ_DIR)/../../modules/Saci/sim/hdl  \
                     $(PROJ_DIR)


# Use top level makefile
include ../../modules/StdLib/build/system_vivado_v1.mk
