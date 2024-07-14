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
ifndef PROJECT
export PROJECT = $(notdir $(PWD))
endif

# Detect project path
ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

# Project Build Directory
ifndef OUT_DIR
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
endif

# Synthesis Variables
export VIVADO_VERSION   = $(shell vivado -version | grep -Po "v(\d+\.)+\d+" | cut -c2-)
export RUCKUS_DIR       = $(TOP_DIR)/submodules/ruckus
export SOURCE_DEPEND    = $(OUT_DIR)/$(PROJECT)_sources.txt

# Source Files
ifndef SRC_FILE
export SRC_FILE = $(PROJ_DIR)/sources.tcl
endif

# Specifies the export configurations
ifndef EXPORT_VENDOR
export EXPORT_VENDOR = SLAC
endif
ifndef EXPORT_VERSION
export EXPORT_VERSION = 1.0
endif

# Update legacy "PRJ_VERSION" variable
export PRJ_VERSION = v$(EXPORT_VERSION)

# Specifies if we need to modify the ip/component.xml to support "all" FPGA family types
ifndef ALL_XIL_FAMILY
export ALL_XIL_FAMILY = 0
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
