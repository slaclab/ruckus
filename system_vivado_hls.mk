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
export PROJECT = $(notdir $(BASE_DIR))
endif

# Project Build Directory
ifndef OUT_DIR
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
endif

# Synthesis Variables
export VIVADO_VERSION   = $(shell vivado -version | grep -Po "(\d+\.)+\d+")
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado_hls)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(PROJECT)_project/$(VIVADO_PROJECT).app
export RUCKUS_DIR       = $(TOP_DIR)/submodules/ruckus
export SOURCE_DEPEND    = $(OUT_DIR)/$(PROJECT)_sources.txt

# Images Directory
ifndef RTL_DIR
export RTL_DIR = $(abspath $(PROJ_DIR)/rtl)
endif

# Source Files
ifndef SRC_FILE
export SRC_FILE = $(PROJ_DIR)/sources.tcl
endif

# HLS Simulation Tool [vcs, xsim, modelsim, ncsim, riviera]
ifndef HLS_SIM_TOOL
export HLS_SIM_TOOL = xsim
endif

define ACTION_HEADER
@echo 
@echo    ================================================================
@echo    $(1)
@echo    "   Project = $(PROJECT)"
@echo    "   Out Dir = $(OUT_DIR)"
@echo -e "   Changed = $(foreach ARG,$?,$(ARG)\n            )"
@echo    ================================================================
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
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo RTL_DIR: $(RTL_DIR)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo VIVADO_PROJECT: $(VIVADO_PROJECT)
	@echo VIVADO_VERSION: $(VIVADO_VERSION)
	@echo SRC_FILE: $(SRC_FILE)
	@echo ARGV: $(ARGV)
	@echo CFLAGS: $(CFLAGS)
	@echo LDFLAGS: $(LDFLAGS)

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : dir
dir:

###############################################################
#### Vivado Project ###########################################
###############################################################
$(VIVADO_DEPEND) :
	vivado -mode batch -source $(RUCKUS_DIR)/vivado_hls_version.tcl
	$(call ACTION_HEADER,"Making output directory")
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
	@test -d $(OUT_DIR) || mkdir $(OUT_DIR)

###############################################################
#### Vivado Sources ###########################################
###############################################################
$(SOURCE_DEPEND) : $(SRC_FILE) $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Project Creation and Source Setup")
	@cd $(OUT_DIR); vivado_hls -f $(RUCKUS_DIR)/vivado_hls_sources.tcl

###############################################################
#### Vivado Batch without design export  ######################
###############################################################
.PHONY : csyn
csyn : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Build without design export")
	@cd $(OUT_DIR); export SKIP_EXPORT=1; vivado_hls -f $(RUCKUS_DIR)/vivado_hls_build.tcl;

######################################################################################
#### Vivado Batch without co-simulation and without design export ####################
######################################################################################
.PHONY : csyn_nocosim
csyn_nocosim : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Build without co-simulation and without design export")
	@cd $(OUT_DIR); export FAST_DCP_GEN=1; export SKIP_EXPORT=1; vivado_hls -f $(RUCKUS_DIR)/vivado_hls_build.tcl;

###############################################################
#### Vivado Batch #############################################
###############################################################
.PHONY : dcp
dcp : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Build")
	@cd $(OUT_DIR); vivado_hls -f $(RUCKUS_DIR)/vivado_hls_build.tcl
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_hls_dcp.tcl

###############################################################
#### Vivado Batch without co-simulation #######################
###############################################################
.PHONY : dcp_nocosim
dcp_nocosim : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Build without co-simulation")
	@cd $(OUT_DIR); export FAST_DCP_GEN=1; vivado_hls -f $(RUCKUS_DIR)/vivado_hls_build.tcl
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_hls_dcp.tcl

###############################################################
#### Vivado Interactive #######################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Interactive")
	@cd $(OUT_DIR); vivado_hls -f $(RUCKUS_DIR)/vivado_hls_interactive.tcl

###############################################################
#### Vivado Gui ###############################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS GUI")
	@cd $(OUT_DIR); vivado_hls -p $(PROJECT)_project

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY  : depend
depend  : $(VIVADO_DEPEND)

.PHONY  : sources
sources : $(SOURCE_DEPEND)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
