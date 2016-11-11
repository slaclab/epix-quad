
# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A200TSBG484-3

export COMMON = $(abspath $(PWD)/../../common)
export MODULES = $(abspath $(PWD)/../../modules)
export RUCKUS_DIR = $(abspath $(PWD)/../../modules/ruckus)


# List of build core directories.
export MODULE_DIRS = $(MODULES)/surf/ \
                     $(PROJ_DIR)

# Max number of smart explorer runs
export SMART_MAX_RUNS = 10

# Use top level makefile
include $(RUCKUS_DIR)/system_vivado.mk
