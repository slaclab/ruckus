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

# HLS Simulation Tool [vcs, xsim, modelsim, ncsim, riviera]
ifndef HLS_SIM_TOOL
export HLS_SIM_TOOL = xsim
endif

# Specifies any co-simulation compiled library paths
ifndef COMPILED_LIB_DIR
export COMPILED_LIB_DIR =
endif

# Specifies any co-simulation compiled library paths
ifndef HLS_SIM_TRACE_LEVEL
export HLS_SIM_TRACE_LEVEL = none
endif

# Specifies the options passed to the flags for C simulation
ifndef CFLAGS
export CFLAGS =
endif

# Specifies the options passed to the linker for C simulation
ifndef LDFLAGS
export LDFLAGS =
endif

# Specifies the options passed to the compiler for C simulation
ifndef MFLAGS
export MFLAGS =
endif

# Specifies the argument list for the C test bench
ifndef ARGV
export ARGV =
endif

# Specifies the synthesis type [verilog, vhdl]
ifndef HDL_TYPE
export HDL_TYPE = verilog
endif

# Specifies if we are skipping the csim
ifndef SKIP_CSIM
export SKIP_CSIM = 0
endif

# Specifies if we are skipping the cosim
ifndef SKIP_COSIM
export SKIP_COSIM = 0
endif

# Specifies if we are skipping the dcp generation
ifndef SKIP_DCP
export SKIP_DCP = 1
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
	@echo SRC_FILE: $(SRC_FILE)
	@echo ARGV: $(ARGV)
	@echo CFLAGS: $(CFLAGS)
	@echo LDFLAGS: $(LDFLAGS)
	@echo HDL_TYPE: $(HDL_TYPE)
	@echo SKIP_CSIM: $(SKIP_CSIM)
	@echo SKIP_COSIM: $(SKIP_COSIM)
	@echo EXPORT_VENDOR: $(EXPORT_VENDOR)
	@echo EXPORT_VERSION: $(PRJ_VERSION)
	@echo HDL_TYPE: $(HDL_TYPE)
	@echo IMAGENAME: $(IMAGENAME)
	@echo BUILD_STRING: $${BUILD_STRING}
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : dir
dir:

###############################################################
#### Vitis HLS Sources ########################################
###############################################################
$(SOURCE_DEPEND) :
	$(call ACTION_HEADER,"Vitis HLS Project Creation and Source Setup")
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
	@cd $(OUT_DIR); vitis_hls -f $(RUCKUS_DIR)/vitis/hls/sources.tcl

###############################################################
#### Vitis HLS Batch Build Mode ###############################
###############################################################
.PHONY : build
build : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vitis HLS Build")
	@cd $(OUT_DIR); vitis_hls -f $(RUCKUS_DIR)/vitis/hls/build.tcl

###############################################################
#### Vitis HLS Interactive ####################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vitis HLS Interactive")
	@cd $(OUT_DIR); vitis_hls -f $(RUCKUS_DIR)/vitis/hls/interactive.tcl

###############################################################
#### Vitis HLS Gui ############################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vitis HLS GUI")
	@cd $(OUT_DIR); vitis_hls -p $(PROJECT)_project

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY  : sources
sources : $(SOURCE_DEPEND)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
