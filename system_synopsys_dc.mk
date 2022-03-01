##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

ifndef DIG_TECH
export DIG_TECH =
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

ifndef DC_CMD
export DC_CMD = dc_shell-xg-t -64bit -topographical_mode
endif

ifndef DC_MSG
export DC_MSG = awk '{ gsub("Warning", "\033[1;43m&\033[0m"); gsub("Error", "\033[1;41m&\033[0m"); print }'
endif

ifndef MODULES
export MODULES = $(TOP_DIR)/submodules
endif

ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export RUCKUS_DC_DIR         = $(RUCKUS_DIR)/synopsys/design_compiler
export RUCKUS_PROC_TCL       = $(RUCKUS_DC_DIR)/proc.tcl
export RUCKUS_PROC_TCL_QUIET = $(RUCKUS_DC_DIR)/proc.tcl

ifndef PARALLEL_SYNTH
export PARALLEL_SYNTH = $(shell cat /proc/cpuinfo | grep processor | wc -l)
endif

ifndef GIT_BYPASS
export GIT_BYPASS = 1
endif

# Project Build Directory
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))
export SYN_DIR = $(OUT_DIR)/syn
export SIM_DIR = $(OUT_DIR)/sim

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

###############################################################

include $(TOP_DIR)/submodules/ruckus/system_shared.mk

# Override system_shared.mk build string
export BUILD_SVR_TYPE = $(shell python -m platform)
export DC_VERSION     = $(shell dc_shell-xg-t -V | grep version | sed 's/ //g' | sed 's/version-/ /g')
export BUILD_STRING   = $(PROJECT): $(DC_VERSION), $(BUILD_SYS_NAME) ($(BUILD_SVR_TYPE)), Built $(BUILD_DATE) by $(BUILD_USER)

# Legacy Vivado Version
export VIVADO_VERSION = -1.0

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
	@echo DC_CMD: $(DC_CMD)
	@echo DC_MSG: $(DC_MSG)
	@echo MODULES: $(MODULES)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo PARALLEL_SYNTH: $(PARALLEL_SYNTH)
	@echo GIT_BYPASS: $(GIT_BYPASS)
	@echo OUT_DIR: $(OUT_DIR)
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
dir:
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
	@test -d $(IMAGES_DIR) || mkdir $(IMAGES_DIR)

###############################################################
#### Synopsys Interactive TCL Mode ############################
###############################################################
.PHONY : interactive
interactive : dir
	$(call ACTION_HEADER,"Synopsys Design Compiler Interactive")
	@cd $(OUT_DIR); $(DC_CMD) | $(DC_MSG)

###############################################################
#### Synopsys Synthesis Mode ##################################
###############################################################
.PHONY : syn
syn : dir
	$(call ACTION_HEADER,"Synopsys Design Compiler Synthesis")
	@cd $(OUT_DIR); $(DC_CMD) -f $(RUCKUS_DC_DIR)/syn.tcl | $(DC_MSG)

###############################################################
#### VCS Simulation ###########################################
###############################################################
.PHONY : vcs
vcs : dir
	$(call ACTION_HEADER,"VCS Simulation")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DC_DIR)/vcs.tcl

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
