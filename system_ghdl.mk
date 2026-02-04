##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

ifndef GIT_BYPASS
export GIT_BYPASS = 1
endif

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

ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export RUCKUS_GHDL_DIR = $(RUCKUS_DIR)/ghdl
export RUCKUS_PROC_TCL = $(RUCKUS_GHDL_DIR)/proc.tcl

# Project Build Directory
ifndef OUT_DIR
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))
endif

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# GHDL build flags
ifndef GHDLFLAGS
export GHDLFLAGS = --workdir=$(OUT_DIR) --std=08 --ieee=synopsys  -frelaxed-rules -fexplicit -Wno-elaboration -Wno-hide -Wno-specs -Wno-shared
endif

# Legacy Vivado Version
export VIVADO_VERSION = -1.0

# Define the top-level entity for 'ghdl -e'
ifndef GHDL_TOP_ENTITY
export GHDL_TOP_ENTITY =
endif

###############################################################

include $(RUCKUS_DIR)/system_shared.mk

# Override system_shared.mk build string
export GHDL_VERSION   = $(shell ghdl -v 2>&1 | head -n 1 | awk '{print $$1, $$2}')
export BUILD_STRING   = $(PROJECT): $(GHDL_VERSION), ${BUILD_SYS_NAME} (${BUILD_SVR_TYPE}), Built ${BUILD_DATE} by ${BUILD_USER}

.PHONY : all
all: target

###############################################################
#### Printout Environmental Variables #########################
###############################################################

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo TOP_DIR: $(TOP_DIR)
	@echo MODULES: $(MODULES)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo GIT_BYPASS: $(GIT_BYPASS)
	@echo OUT_DIR: $(OUT_DIR)
	@echo GHDLFLAGS: $(GHDLFLAGS)
	@echo BUILD_STRING: $${BUILD_STRING}
	@echo IMAGENAME: $(IMAGENAME)
	@echo IMAGES_DIR: $(IMAGES_DIR)
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)
	@echo Untracked Files:
	@echo "\t$(foreach ARG,$(GIT_STATUS),  $(ARG)\n)"

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : dir
dir: clean
	@test -d $(OUT_DIR) || mkdir $(OUT_DIR)

###############################################################
#### Load the Source Code #####################################
###############################################################
.PHONY : load_source_code
load_source_code : dir
	$(call ACTION_HEADER,"GHDL: Load the Source Code")
	@$(RUCKUS_DIR)/ghdl/load_source_code.tcl

###############################################################
#### Import ###################################################
###############################################################
.PHONY : import
import : load_source_code
	$(call ACTION_HEADER,"GHDL: Import (ghdl -i)")
	@$(RUCKUS_DIR)/ghdl/import.tcl

###############################################################
#### Analyze  #################################################
###############################################################
.PHONY : analysis
analysis : load_source_code
	$(call ACTION_HEADER,"GHDL: Analyze (ghdl -a)")
	@$(RUCKUS_DIR)/ghdl/analysis.tcl

###############################################################
#### Elaboration   ############################################
###############################################################
.PHONY : elaboration
elaboration : analysis
	$(call ACTION_HEADER,"GHDL: Elaboration (ghdl -e)")
	@ghdl -e $(GHDLFLAGS) -P$(OUT_DIR) $(GHDL_TOP_ENTITY)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
