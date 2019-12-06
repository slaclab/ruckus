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
export PRJ_VERSION = 0xFFFFFFFF
endif

ifndef REMOVE_UNUSED_CODE
export REMOVE_UNUSED_CODE = 0
endif

ifndef PARALLEL_SYNTH
export PARALLEL_SYNTH = $(shell cat /proc/cpuinfo | grep processor | wc -l)
endif

ifndef GIT_BYPASS
export GIT_BYPASS = 1
endif

ifndef GZIP_BUILD_IMAGE
export GZIP_BUILD_IMAGE = 0
endif

ifndef GEN_BIN_IMAGE
export GEN_BIN_IMAGE = 0
endif

ifndef RECONFIG_CHECKPOINT
export RECONFIG_CHECKPOINT = 0
export RECONFIG_STATIC_HASH = 0
else
export RECONFIG_STATIC_FILE = $(notdir $(RECONFIG_CHECKPOINT))
export RECONFIG_STATIC_HASH = -$(shell echo '$(RECONFIG_STATIC_FILE)' | awk -F'-' '{print $$5}' )
endif

ifndef RECONFIG_ENDPOINT
export RECONFIG_ENDPOINT = 0
endif

ifndef RECONFIG_PBLOCK
export RECONFIG_PBLOCK = 0
endif

# Check for /u1 drive
BUILD_EXIST=$(shell [ -e  $(TOP_DIR)/build/ ] && echo 1 || echo 0 )
U1_EXIST=$(shell [ -e /u1/ ] && echo 1 || echo 0 )
ifeq ($(U1_EXIST), 1)
   $(shell mkdir -p /u1/$(USER) )
   $(shell mkdir -p /u1/$(USER)/build )
   ifeq ($(BUILD_EXIST), 0)
      $(shell ln -s /u1/$(USER)/build $(TOP_DIR)/build )
   endif
endif
U1_EXIST=$(shell [ -e /u1/$(USER)/build ] && echo 1 || echo 0 )
ifeq ($(U1_EXIST), 1)
   export TMP_DIR=/u1/$(USER)/build
else
   export TMP_DIR=/tmp/build
endif

# Vivado Simulation Variables
ifndef VIVADO_PROJECT_SIM
export VIVADO_PROJECT_SIM = $(PROJECT)
endif
ifndef VIVADO_PROJECT_SIM_TIME
export VIVADO_PROJECT_SIM_TIME = 1000 ns
endif

# Synthesis Variables
export VIVADO_VERSION   = $(shell vivado -version | grep -Po "(\d+\.)+\d+")
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(VIVADO_PROJECT).xpr
ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export SOURCE_DEPEND    = $(OUT_DIR)/$(PROJECT)_sources.txt

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Project Build Directory
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
export SYN_DIR  = $(OUT_DIR)/$(VIVADO_PROJECT).runs/synth_1
export IMPL_DIR = $(OUT_DIR)/$(VIVADO_PROJECT).runs/impl_1

# Generate build string
export BUILD_SYS_NAME    = $(shell uname -n)
export BUILD_SVR_TYPE    = $(shell uname -m)
export BUILD_USER   = $(shell whoami)
BUILD_DATE := $(shell date)
BUILD_TIME := $(shell date +%Y%m%d%H%M%S)
export BUILD_STRING = $(PROJECT): Vivado v$(VIVADO_VERSION), $(BUILD_SYS_NAME) ($(BUILD_SVR_TYPE)), Built $(BUILD_DATE) by $(BUILD_USER)

# Check the GIT status
export GIT_STATUS = $(shell git diff-index --name-only HEAD)

# Check for non-dirty git clone
ifeq ($(GIT_STATUS),)
   export GIT_HASH_LONG  = $(shell git rev-parse HEAD)
   export GIT_HASH_SHORT = $(shell git rev-parse --short HEAD)
   export GIT_HASH_MSG   = $(GIT_HASH_LONG)
   ifeq ($(RECONFIG_STATIC_HASH), 0)
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-$(GIT_HASH_SHORT)
   else
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-$(GIT_HASH_SHORT)$(RECONFIG_STATIC_HASH)
   endif
else
   export GIT_HASH_MSG   = dirty
   # Check if we are using GIT tagging
   ifeq ($(GIT_BYPASS), 0)
      export GIT_HASH_LONG  = 
      export GIT_HASH_SHORT = 
   else
      export GIT_STATUS     = 
      export GIT_HASH_LONG  = 0
      export GIT_HASH_SHORT = 0
   endif
   ifeq ($(RECONFIG_STATIC_HASH), 0)
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-dirty
   else
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-dirty$(RECONFIG_STATIC_HASH)
   endif
endif

# https://www.xilinx.com/support/answers/63253.html
export XILINX_LOCAL_USER_DATA = no

# SDK Variables
export SDK_PRJ    = $(abspath $(OUT_DIR)/$(VIVADO_PROJECT).sdk)
export SDK_ELF    = $(abspath $(SDK_PRJ)/$(PROJECT).elf)
ifndef LD_PRELOAD
export LD_PRELOAD = 
endif

ifndef SDK_LIB
export SDK_LIB  =  $(MODULES)/surf/xilinx/general/sdk/common
endif

# Ubuntu SDK support
ifndef SWT_GTK3
export SWT_GTK3 = 0
endif

define ACTION_HEADER
@echo
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project      = $(PROJECT)"
@echo    "   Out Dir      = $(OUT_DIR)"
@echo    "   Version      = $(PRJ_VERSION)"
@echo    "   Build String = $(BUILD_STRING)"
@echo    "   GIT Hash     = $(GIT_HASH_MSG)"
@echo    "============================================================================="
@echo
endef

define COPY_PROBES_FILE
@if [ -f '$(OUT_DIR)/debugProbes.ltx' ] ; then \
	$(RM) '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	cp '$(OUT_DIR)/debugProbes.ltx' '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	echo "Debug Probes file copied to $(IMAGES_DIR)/$(IMAGENAME).ltx "; \
elif  [ -f '$(IMPL_DIR)/debug_nets.ltx' ] ; then \
	$(RM) '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	cp '$(IMPL_DIR)/debug_nets.ltx' '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	echo "Debug Probes file copied to $(IMAGES_DIR)/$(IMAGENAME).ltx "; \
else \
	echo "No Debug Probes found"; \
fi
endef

.PHONY : all
all: target

###############################################################
#### Printout Environmental Variables #########################
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
	@echo XILINX_LOCAL_USER_DATA: $(XILINX_LOCAL_USER_DATA)
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)
	@echo IMAGENAME: $(IMAGENAME)
	@echo Untracked Files:
	@echo "\t$(foreach ARG,$(GIT_STATUS),  $(ARG)\n)"

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
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_project.tcl -notrace 

###############################################################
#### Vivado Sources ###########################################
###############################################################
$(SOURCE_DEPEND) : $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado Source Setup")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_sources.tcl

###############################################################
#### Vivado Batch #############################################
###############################################################
.PHONY : bit mcs prom
bit mcs prom: $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Batch Build for .bit/.mcs")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl
	@echo "Don't forget to 'git commit and git push' the images file when the image is stable!"

###############################################################
#### Vivado Interactive #######################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Interactive")
	@cd $(OUT_DIR); vivado -mode tcl -source $(RUCKUS_DIR)/vivado_env_var.tcl

###############################################################
#### Vivado Project GUI mode ##################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Project GUI Mode")
	@cd $(OUT_DIR); vivado -source $(RUCKUS_DIR)/vivado_gui.tcl $(VIVADO_PROJECT).xpr

###############################################################
#### Vivado No Gui ############################################
###############################################################
.PHONY : nogui
nogui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado GUI")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_gui.tcl $(VIVADO_PROJECT).xpr

###############################################################
#### Vivado Sythnesis Only ####################################
###############################################################
.PHONY : syn
syn : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis Only")
	@cd $(OUT_DIR); export SYNTH_ONLY=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl

###############################################################
#### Vivado Synthesis DCP  ####################################
###############################################################
.PHONY : dcp
dcp : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis DCP")
	@cd $(OUT_DIR); export SYNTH_DCP=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl

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
#### Vivado CPSW ##############################################
###############################################################
.PHONY : yaml
yaml : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generaring cpsw.tar.gz file")
	@cd $(OUT_DIR); tclsh $(RUCKUS_DIR)/vivado_cpsw.tcl

###############################################################
#### Vivado WIS ###############################################
###############################################################
.PHONY : wis
wis : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generating init_wis.tcl file for Windows OS")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_wis.tcl

###############################################################
#### Vivado XSIM Simulation ###################################
###############################################################
.PHONY : xsim
xsim : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado XSIM Simulation")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_xsim.tcl

###############################################################
#### Vivado VCS Simulation ####################################
###############################################################
.PHONY : vcs
vcs : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generating the VCS Simulation scripts")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_vcs.tcl

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY      : depend
depend      : $(VIVADO_DEPEND)

.PHONY      : sources
sources     : $(SOURCE_DEPEND)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
