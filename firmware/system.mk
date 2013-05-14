
# Detect project name
export PROJECT = $(notdir $(PWD))

# Top level directory
export PROJ_DIR = $(abspath $(PWD))
export TOP_DIR = $(abspath $(PROJ_DIR)/../..)

# Project Build Directory
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))

# Location of synthesis options files
export CONFIG_DIR = $(abspath $(PROJ_DIR)/config)

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Project RTL Location
export PRJ_RTL     = $(abspath $(PROJ_DIR)/hdl)

# UCF File (always in PRJ_RTL/PROJECT.ucf)
export UCF_FILE = $(abspath $(PRJ_RTL)/$(PROJECT).ucf)

# Get Project Version
export PRJ_VERSION = $(shell grep MAKE_VERSION $(PROJ_DIR)/Version.vhd | cut -d ' ' -f 8 | cut -d'"' -f2)

# Get Project Part
export PRJ_PART = $(shell grep '^-p ' $(PROJ_DIR)/config/xst_options.txt | cut -d ' ' -f 2)

define ACTION_HEADER
@echo 
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project = $(PROJECT)"
@echo    "   Out Dir = $(OUT_DIR)"
@echo    "   Version = $(PRJ_VERSION)"
@echo -e "   Changed = $(foreach ARG,$?,$(ARG)\n            )"
@echo    "============================================================================="
@echo 	
endef

.PHONY : all
all: target

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo PRJ_VERSION: $(PRJ_VERSION)
	@echo PRJ_PART: $(PRJ_PART)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo CONFIG_DIR: $(CONFIG_DIR)
	@echo XST_OPTIONS_FILE $(XST_OPTIONS_FILE)
	@echo RAW_SOURCES_FILE $(RAW_SOURCES_FILE)
	@echo OUT_SOURCES_FILE $(OUT_SOURCES_FILE)
	@echo RTL_FILES: 
	@echo -e "$(foreach ARG,$(RTL_FILES),  $(ARG)\n)"

#### Build Location ########################################
.PHONY : dir
dir:

#### Check Source Files ###################################
%.vhd : 
	@test -d $*.vhd || echo "$*.vhd does not exist"; false;

%.v : 
	@test -d $*.v || echo "$*.v does not exist"; false;

#### Synthesis #############################################
XST_OPTIONS_FILE = $(CONFIG_DIR)/xst_options.txt
RAW_SOURCES_FILE = $(CONFIG_DIR)/sources.txt
OUT_SOURCES_FILE = $(OUT_DIR)/sources.txt

RTL_FILES = $(abspath $(subst _PROJ_DIR_,$(PROJ_DIR),$(shell grep -o _PROJ_DIR_\.\*.[vhd,v] $(RAW_SOURCES_FILE))))

%.ngc : $(RTL_FILES) $(XST_OPTIONS_FILE) $(RAW_SOURCES_FILE) 
	$(call ACTION_HEADER,"Synthesize")
	@test -d $(TOP_DIR)/build/ || { \
          echo ""; \
          echo "Build directory missing!"; \
          echo "You must create a build directory at the top level."; \
          echo ""; \
          echo "This directory can either be a normal directory:"; \
          echo "   mkdir $(TOP_DIR)/build"; \
          echo ""; \
          echo "Or by creating a symbolic link to a directory on another disk:"; \
          echo "   ln -s /tmp/build $(TOP_DIR)/build"; \
          echo ""; false; }
	@test -d $(OUT_DIR)     || mkdir $(OUT_DIR)
	@test -d $(OUT_DIR)/tmp || mkdir $(OUT_DIR)/tmp
	@test -d $(OUT_DIR)/xst/ || mkdir $(OUT_DIR)/xst/
	@test -d $(OUT_DIR)/xst/tmp || mkdir $(OUT_DIR)/xst/tmp
	@rm -f $(OUT_SOURCES_FILE)
	@sed 's|_PROJ_DIR_|$(PROJ_DIR)|' $(RAW_SOURCES_FILE) > $(OUT_SOURCES_FILE)
	@cd $(OUT_DIR); xst  -ifn $(XST_OPTIONS_FILE) -ofn $*.srp

#### Translate #############################################
TRANSLATE_OPTIONS_FILE = $(CONFIG_DIR)/ngdbuild_options.txt
TRANSLATE_INPUT = .ngc #Override with .ngo to use ChipScope core inserter output
ifneq ($(BOOT_ELF),)
  dep_bmm := $(PROJ_DIR)/boot/$(PROJECT).bmm
  opt_bmm := -bm $(PROJ_DIR)/boot/$(PROJECT).bmm
endif
%.ngd: %$(TRANSLATE_INPUT) $(UCF_FILE) $(TRANSLATE_OPTIONS_FILE) $(dep_bmm)
	$(call ACTION_HEADER,"Translate")
	@cd $(OUT_DIR);	ngdbuild \
	  -sd $(OUT_DIR) \
	  $(foreach ARG,$(CORE_DIRS),-sd $(abspath $(ARG))) \
	  -f $(TRANSLATE_OPTIONS_FILE) \
    $(opt_bmm) \
	  -dd $(OUT_DIR)/bld \
	  -uc $(UCF_FILE) \
	  $*$(TRANSLATE_INPUT) $*.ngd

#### Map ###################################################
MAP_OPTIONS_FILE = $(CONFIG_DIR)/map_options.txt
%_map.ncd %.pcf: %.ngd $(MAP_OPTIONS_FILE)
	$(call ACTION_HEADER,"Map")
	@cd $(OUT_DIR); map \
	  -w \
	  -f $(MAP_OPTIONS_FILE) \
	  -o $*_map.ncd \
	  $*.ngd $*.pcf

#### PAR ###################################################
PAR_OPTIONS_FILE = $(CONFIG_DIR)/par_options.txt
%.ncd: %_map.ncd %.pcf $(PAR_OPTIONS_FILE)
	$(call ACTION_HEADER,"Place and Route")
	@cd $(OUT_DIR); par \
	  -w \
	  -f $(PAR_OPTIONS_FILE) \
	  $*_map.ncd \
	  $*.ncd $*.pcf

#### Trace #################################################
TRCE_OPTIONS_FILE =  $(CONFIG_DIR)/trce_options.txt
%.twr: %.ncd %.pcf $(TRCE_OPTIONS_FILE)
	$(call ACTION_HEADER,"Trace")
	@cd $(OUT_DIR); trce \
	  -f $(TRCE_OPTIONS_FILE) \
	  -o $*.twr \
	  $*.ncd $*.pcf

#### Bit ###################################################
BIT_OPTIONS_FILE = $(CONFIG_DIR)/bitgen_options.txt
ifneq ($(BOOT_ELF),)
  dep_elf := $(BOOT_ELF)
  opt_elf := -bd $(BOOT_ELF)
endif
%.bit: %.ncd $(BIT_OPTIONS_FILE) $(dep_elf)
	$(call ACTION_HEADER,"Bitgen")
	@cd $(OUT_DIR); bitgen \
    $(opt_elf) \
	  -f $(BIT_OPTIONS_FILE) $(opt_elf) \
	  $*.ncd

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit : $(OUT_DIR)/$(PROJECT).bit
	@cp $< $@
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"


#### PROM ##################################################
PROM_OPTIONS_FILE = $(CONFIG_DIR)/promgen_options.txt
%.mcs: %.bit $(PROM_OPTIONS_FILE)
	$(call ACTION_HEADER,"PROM Generate")
	@cd $(OUT_DIR); promgen \
	  -f $(PROM_OPTIONS_FILE) \
	  -u 0 $*.bit 

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs : $(OUT_DIR)/$(PROJECT).mcs
	@cp $< $@
	@echo ""
	@echo "Prom file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### BOOTGEN ##################################################
BOOTGEN_CONFIG_FILE  = $(PROJ_DIR)/boot/bootgen.bif
BOOTGEN_CONFIG_OUT   = $(OUT_DIR)/bootgen.bif
%.bin: %.bit $(BOOTGEN_CONFIG_FILE)
	$(call ACTION_HEADER,"Boot Image Generate")
	@rm -f $(BOOTGEN_CONFIG_OUT)
	@sed 's|_PROJ_DIR_|$(PROJ_DIR)|' $(BOOTGEN_CONFIG_FILE) \
   | sed 's|_PROJECT_|$(PROJECT)|' > $(BOOTGEN_CONFIG_OUT)
	@cd $(OUT_DIR); bootgen -w \
	  -image $(BOOTGEN_CONFIG_OUT) \
	  -o i $*.bin

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bin : $(OUT_DIR)/$(PROJECT).bin
	@cp $< $@
	@echo ""
	@echo "Boot file generated at $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### SPLIT ##################################################
%.split: %.bit %.bin $(BOOTGEN_CONFIG_FILE)
	$(call ACTION_HEADER,"Split Image Generate")
	@cd $(OUT_DIR); bootgen -w \
	  -image $(BOOTGEN_CONFIG_OUT) \
	  -split bin -o i temp.bin; mv $(PROJECT).bit.bin $(PROJECT).split

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).split : $(OUT_DIR)/$(PROJECT).split
	@cp $< $@
	@echo ""
	@echo "Split bit file generated at $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### Smart Explorer #############################################
SMART_OPTIONS_FILE = $(CONFIG_DIR)/smart_options.txt
SMART_HOSTS_FILE   = $(CONFIG_DIR)/smart_hosts.txt
%.smart: %.ngd $(SMART_OPTIONS_FILE) $(SMART_HOSTS_FILE)
	$(call ACTION_HEADER,"Smart Explorer")
	@cd $(OUT_DIR);	smartxplorer \
     -part $(PRJ_PART) \
     -m $(SMART_MAX_RUNS) \
     -wd $(OUT_DIR)/smart/ \
     -sf $(SMART_OPTIONS_FILE) \
     -l  $(SMART_HOSTS_FILE) \
	  $*.ngd;

#### Makefile Targets ######################################
.PHONY : syn
syn    : $(OUT_DIR)/$(PROJECT).ngc 

.PHONY    : translate
translate : $(OUT_DIR)/$(PROJECT).ngd

.PHONY : smart
smart  : $(OUT_DIR)/$(PROJECT).smart

.PHONY : map
map    : $(OUT_DIR)/$(PROJECT)_map.ncd

.PHONY : par
par    : $(OUT_DIR)/$(PROJECT).ncd

.PHONY : trce
trce   : $(OUT_DIR)/$(PROJECT).twr

.PHONY : bit
bit    : $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit 

.PHONY : prom
prom   : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs

.PHONY  : bootgen
bootgen : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bin

.PHONY  : split
split   : bit bootgen $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).split

#### Clean #################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR) 

