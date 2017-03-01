##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

ifndef PROJECT
export PROJECT = $(notdir $(PWD))
endif

ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

ifndef TOP_DIR
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)
endif

ifndef MODULES
export MODULES = $(TOP_DIR)/submodules
endif

ifndef PRJ_VERSION
export PRJ_VERSION = 
endif

ifndef REMOVE_UNUSED_CODE
export REMOVE_UNUSED_CODE = 0
endif

# Project Build Directory
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
export SYN_DIR  = $(OUT_DIR)/$(VIVADO_PROJECT).runs/synth_1
export IMPL_DIR = $(OUT_DIR)/$(VIVADO_PROJECT).runs/impl_1

# Check for /u1 drive
U1_EXIST=$(shell [ -e /u1/$(USER)/build ] && echo 1 || echo 0 )
ifeq ($(U1_EXIST), 1)
   export TMP_DIR=/u1/$(USER)/build
else    
   export TMP_DIR=/tmp/build
endif

# Synthesis Variables
export VIVADO_VERSION   = $(shell vivado -version | grep -Po "(\d+\.)+\d+")
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(PROJECT)_project.xpr
ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export SOURCE_DEPEND    = $(OUT_DIR)/$(PROJECT)_sources.txt

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Generate build string
export BUILD_SYS    = $(shell uname -m)
export BUILD_DATE   = $(shell date)
export BUILD_TIME   = $(shell date +%Y%m%d%H%M%S)
export BUILD_USER   = $(shell whoami)
export BUILD_STRING = $(PROJECT): Vivado v$(VIVADO_VERSION), $(BUILD_SYS), Built $(BUILD_DATE) by $(BUILD_USER)

# Check if we are using GIT tagging
ifndef GIT_BYPASS
export GIT_BYPASS = 0
endif
ifeq ($(GIT_BYPASS), 0)
   # Check the GIT status
   export GIT_STATUS = $(shell git diff-index HEAD --name-only)
   ifeq ($(GIT_STATUS),)
      export GIT_TAG_NAME =  build.$(PROJECT).$(PRJ_VERSION).$(BUILD_TIME)
      export GIT_TAG_MSG  = -m "PROJECT: $(PROJECT)" -m "FW_VERSION: $(PRJ_VERSION)" -m "BUILD_STRING: $(BUILD_STRING)"
      export GIT_HASH_LONG  = $(shell git rev-parse HEAD)
      export GIT_HASH_SHORT = $(shell git rev-parse --short HEAD)
      export GIT_HASH_MSG   = $(GIT_HASH_LONG)
   else 
      export GIT_TAG_NAME   = Uncommitted code detected
      export GIT_TAG_MSG    = 
      export GIT_HASH_LONG  = 
      export GIT_HASH_SHORT = 
      export GIT_HASH_MSG   = dirty
   endif
   # Generate common filename
   export IMAGENAME = $(PROJECT)_$(PRJ_VERSION)_$(BUILD_TIME)_$(GIT_HASH_SHORT)
   
else 
   export GIT_STATUS     =
   export GIT_TAG_NAME   = Bypassing Build GIT Tagging
   export GIT_TAG_MSG    =
   export GIT_HASH_LONG  = 0
   export GIT_HASH_SHORT = 0
   export GIT_HASH_MSG   = dirty
   export IMAGENAME      = $(PROJECT)_$(PRJ_VERSION)_$(BUILD_TIME)-dirty
endif

# SDK Variables
export SDK_PRJ    = $(abspath $(OUT_DIR)/$(VIVADO_PROJECT).sdk)
export SDK_ELF    = $(abspath $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).elf)
export LD_PRELOAD = 

ifndef SDK_LIB
export SDK_LIB  =  $(MODULES)/surf/xilinx/general/sdk/common
endif

define ACTION_HEADER
@echo 
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project      = $(PROJECT)"
@echo    "   Out Dir      = $(OUT_DIR)"
@echo    "   Version      = $(PRJ_VERSION)"
@echo    "   Build String = $(BUILD_STRING)"
@echo    "   GIT Tag      = $(GIT_TAG_NAME)"
@echo    "   GIT Hash     = $(GIT_HASH_MSG)"
@echo    "============================================================================="
@echo 	
endef

.PHONY : all
all: target

###############################################################
#### Printout Env. Variables ##################################
###############################################################

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo PRJ_VERSION: $(PRJ_VERSION)
	@echo PRJ_PART: $(PRJ_PART)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo IMAGES_DIR: $(IMAGES_DIR)
	@echo IMPL_DIR: $(IMPL_DIR)
	@echo VIVADO_DIR: $(VIVADO_DIR)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo VIVADO_PROJECT: $(VIVADO_PROJECT)
	@echo VIVADO_VERSION: $(VIVADO_VERSION)
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)
	@echo IMAGENAME: $(GIT_TAG_CMD)
	@echo Untracked Files:
	@echo -e "$(foreach ARG,$(GIT_STATUS),  $(ARG)\n)"

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : dir
dir:

###############################################################
#### Vivado Project ###########################################
###############################################################
$(VIVADO_DEPEND) :
	$(call ACTION_HEADER,"Vivado Project Creation")
	@test -d $(TOP_DIR)/build/ || { \
			 echo ""; \
			 echo "Build directory missing!"; \
			 echo "You must create a build directory at the top level."; \
			 echo ""; \
			 echo "This directory can either be a normal directory:"; \
			 echo "   mkdir $(TOP_DIR)/build"; \
			 echo ""; \
			 echo "Or by creating a symbolic link to a directory on another disk:"; \
			 echo "   ln -s $(TMP_DIR) $(TOP_DIR)/build"; \
			 echo ""; false; }
	@test -d $(OUT_DIR) || mkdir $(OUT_DIR)
	@cd $(OUT_DIR); rm -f firmware
	@cd $(OUT_DIR); ln -s $(TOP_DIR) firmware
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_project.tcl

###############################################################
#### Vivado Sources ###########################################
###############################################################
$(SOURCE_DEPEND) : $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado Source Setup")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_sources.tcl

###############################################################
#### Vivado Batch #############################################
###############################################################
$(IMPL_DIR)/$(PROJECT).bit : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Build")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl
#### Vivado Batch (Partial Reconfiguration: Static) ###########
$(IMPL_DIR)/$(PROJECT)_static.bit : $(RTL_FILES) $(XDC_FILES) $(TCL_FILES) $(CORE_FILES) $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Build (Partial Reconfiguration: Static)")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build_static.tcl
#### Vivado Batch (Partial Reconfiguration: Dynamic) ##########
$(IMPL_DIR)/$(PROJECT)_dynamic.bit : $(RTL_FILES) $(XDC_FILES) $(TCL_FILES) $(CORE_FILES) $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Build (Partial Reconfiguration: Dynamic)")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build_dynamic.tcl

###############################################################
#### Bitfile Copy #############################################
###############################################################
$(IMAGES_DIR)/$(IMAGENAME).bit : $(IMPL_DIR)/$(PROJECT).bit
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'git commit and git push' the .bit.gz file when the image is stable!"
#### Bitfile Copy (Partial Reconfiguration: Static) ###########
$(IMAGES_DIR)/$(IMAGENAME)_static.bit : $(IMPL_DIR)/$(PROJECT)_static.bit
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'git commit and git push' the .bit.gz file when the image is stable!"
$(IMAGES_DIR)/$(IMAGENAME)_static.dcp : $(IMPL_DIR)/$(PROJECT)_static.dcp
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Checkpoint file copied to $@"
	@echo "Don't forget to 'git commit and git push' the .dcp file when the image is stable!"
#### Bitfile Copy (Partial Reconfiguration: Dynamic) ##########
$(IMAGES_DIR)/$(IMAGENAME)_dynamic.bit : $(IMPL_DIR)/$(PROJECT)_dynamic.bit
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'git commit and git push' the .bit.gz file when the image is stable!" 

###############################################################
#### Vivado Interactive #######################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Interactive")
	@cd $(OUT_DIR); vivado -mode tcl -source $(RUCKUS_DIR)/vivado_env_var.tcl

###############################################################
#### Vivado Gui ###############################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado GUI")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_gui.tcl

###############################################################
#### Vivado VCS ###############################################
###############################################################
.PHONY : vcs
vcs : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado VCS")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_vcs.tcl

###############################################################
#### Vivado Sythnesis Only ####################################
###############################################################
.PHONY : syn
syn : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis Only")
	@cd $(OUT_DIR); export SYNTH_ONLY=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl

###############################################################
#### Vivado Sythnesis DCP  ####################################
###############################################################
.PHONY : dcp
dcp : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis DCP")
	@cd $(OUT_DIR); export SYNTH_DCP=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl

###############################################################
#### Prom #####################################################
###############################################################
$(IMAGES_DIR)/$(IMAGENAME).mcs: $(IMPL_DIR)/$(PROJECT).bit
	$(call ACTION_HEADER,"PROM Generate")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_promgen.tcl
	@echo ""
	@echo "Prom file copied to $@"
	@echo "Don't forget to 'git commit and git push' the .mcs.gz file when the image is stable!" 

###############################################################
#### Vivado SDK ###############################################
###############################################################
.PHONY : sdk
sdk : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado SDK GUI")
	@cd $(OUT_DIR); xsdk -workspace $(OUT_DIR)/$(VIVADO_PROJECT).sdk \
      -vmargs -Dorg.eclipse.swt.internal.gtk.cairoGraphics=false

###############################################################
#### Vivado SDK ELF ###########################################
###############################################################
.PHONY : elf
elf : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado SDK .ELF generation")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_sdk_bit.tcl
	@echo ""
	@echo "Bit file w/ Elf file copied to $(IMAGES_DIR)/$(IMAGENAME).bit"
	@echo "Don't forget to 'git commit and git push' the .bit.gz file when the image is stable!"   

###############################################################
#### Vivado YAML ##############################################
###############################################################
.PHONY : yaml
yaml : $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Generaring YAML.tar.gz file")
	@cd $(OUT_DIR); tclsh $(RUCKUS_DIR)/vivado_yaml.tcl

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY      : depend
depend      : $(VIVADO_DEPEND)

.PHONY      : sources
sources     : $(SOURCE_DEPEND)

.PHONY      : bit
bit         : $(IMAGES_DIR)/$(IMAGENAME).bit 

.PHONY      : bit_static
bit_static  : $(IMAGES_DIR)/$(IMAGENAME)_static.bit $(IMAGES_DIR)/$(IMAGENAME)_static.dcp 

.PHONY      : bit_dynamic
bit_dynamic : $(IMAGES_DIR)/$(IMAGENAME)_dynamic.bit

.PHONY      : prom
prom        : bit $(IMAGES_DIR)/$(IMAGENAME).mcs

.PHONY      : prom_static
prom_static : bit_static $(IMAGES_DIR)/$(IMAGENAME).mcs

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
