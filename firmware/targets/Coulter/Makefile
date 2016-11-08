
# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A200TSBG484-3

export COMMON = $(abspath $(PWD)/../../common)
export MODULES = $(abspath $(PWD)/../../modules)
export RUCKUS_DIR = $(abspath $(PWD)/../../modules/ruckus)


# List of build core directories.
export MODULE_DIRS = $(MODULES)/surf/base  \
                     $(MODULES)/surf/axi \
                     $(MODULES)/surf/protocols/ssi \
                     $(MODULES)/surf/protocols/srp \
                     $(MODULES)/surf/protocols/i2c \
                     $(MODULES)/surf/protocols/spi \
                     $(MODULES)/surf/protocols/pgp/pgp2b/core \
                     $(MODULES)/surf/protocols/pgp/pgp2b/gtp7 \
                     $(MODULES)/surf/xilinx/general \
                     $(MODULES)/surf/xilinx/7Series/gtp7 \
                     $(MODULES)/surf/xilinx/7Series/general \
                     $(MODULES)/surf/devices/AnalogDevices/ad9249 \
                     $(PROJ_DIR)

# Max number of smart explorer runs
export SMART_MAX_RUNS = 10

# Use top level makefile
include $(RUCKUS_DIR)/system_vivado_v1.mk
