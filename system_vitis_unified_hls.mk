##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Detect project name
export PROJECT = $(notdir $(PWD))

# Detect project path
export PROJ_DIR = $(abspath $(PWD))

# Project Build Directory ("workspace")
export OUT_DIR  = $(PROJ_DIR)/build

# Build System Variables
export VIVADO_VERSION = $(shell vivado -version | grep -Po "v(\d+\.)+\d+" | cut -c2-)
export RUCKUS_DIR     = $(TOP_DIR)/submodules/ruckus

# Specifies if we need to modify the ip/component.xml to support "all" FPGA family types
ifndef ALL_XIL_FAMILY
export ALL_XIL_FAMILY = 1
endif

include $(TOP_DIR)/submodules/ruckus/system_shared.mk

.PHONY : all
all: target

###############################################################
#### Printout Env. Variables ##################################
###############################################################
.PHONY : test
test:
	@echo VIVADO_VERSION: $(VIVADO_VERSION)
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo BUILD_STRING: $${BUILD_STRING}
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : proj
proj:
	$(call ACTION_HEADER,"Vitis HLS Create Project")
	@test -d $(OUT_DIR)     || mkdir $(OUT_DIR)
	@test -d $(PROJ_DIR)/ip || mkdir $(PROJ_DIR)/ip
	@cd $(OUT_DIR); vitis -s $(RUCKUS_DIR)/vitis/hls/create_proj.py

###############################################################
#### Vitis HLS Batch Build Mode ###############################
###############################################################
.PHONY : build
build : proj
	$(call ACTION_HEADER,"Vitis HLS Build")
	@cd $(OUT_DIR); vitis -s $(RUCKUS_DIR)/vitis/hls/build.py

###############################################################
#### Vitis HLS Interactive ####################################
###############################################################
.PHONY : interactive
interactive : proj
	$(call ACTION_HEADER,"Vitis HLS Interactive")
	@cd $(OUT_DIR); vitis -i

###############################################################
#### Vitis HLS Gui ############################################
###############################################################
.PHONY : gui
gui : proj
	$(call ACTION_HEADER,"Vitis Unified IDE")
	@cd $(OUT_DIR); vitis -w $(OUT_DIR)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
