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

ifndef MAX_CORES
export MAX_CORES = 8
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

ifndef PDK_PATH
export PDK_PATH =
endif

ifndef OPERATING_CONDITION
export OPERATING_CONDITION = tt0p9v25c
endif

ifndef STD_CELL_LIB
export STD_CELL_LIB =
endif

ifndef STD_LEF_LIB
export STD_LEF_LIB =
endif

ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export RUCKUS_GENUS_DIR  = $(RUCKUS_DIR)/cadence/genus
export RUCKUS_PROC_TCL   = $(RUCKUS_GENUS_DIR)/proc.tcl
export RUCKUS_QUIET_FLAG = -quiet

# Project Build Directory
export OUT_DIR     = $(abspath $(TOP_DIR)/build/$(PROJECT))
export SYN_DIR     = $(OUT_DIR)/syn
export SYN_OUT_DIR = $(OUT_DIR)/syn/out
export SIM_DIR     = $(OUT_DIR)/sim

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

###############################################################

include $(TOP_DIR)/submodules/ruckus/system_shared.mk

# Override system_shared.mk build string
export GENUS_VERSION = $(shell genus -version | grep Version: | sed 's/.*Version: //')
export BUILD_STRING  = $(PROJECT): $(GENUS_VERSION), $(BUILD_SYS_NAME) ($(BUILD_SVR_TYPE)), Built $(BUILD_DATE) by $(BUILD_USER)

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
	@echo MODULES: $(MODULES)
	@echo MAX_CORES: $(MAX_CORES)
	@echo PDK_PATH: $(PDK_PATH)
	@echo OPERATING_CONDITION: $(OPERATING_CONDITION)
	@echo STD_CELL_LIB: $(STD_CELL_LIB)
	@echo STD_LEF_LIB: $(STD_LEF_LIB)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo GIT_BYPASS: $(GIT_BYPASS)
	@echo OUT_DIR: $(OUT_DIR)
	@echo SYN_DIR: $(SYN_DIR)
	@echo SYN_OUT_DIR: $(SYN_OUT_DIR)
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
#### Cadence Synthesis Mode ###################################
###############################################################
.PHONY : syn
syn : dir
	$(call ACTION_HEADER,"Cadence Genus Synthesis")
	@rm -rf $(SYN_DIR); mkdir $(SYN_DIR);
	@mkdir $(SYN_OUT_DIR); mkdir $(SYN_OUT_DIR)/reports; mkdir $(SYN_OUT_DIR)/svf
	@cd $(SYN_DIR); genus -f $(RUCKUS_GENUS_DIR)/syn.tcl

###############################################################
#### VCS Simulation ###########################################
###############################################################
.PHONY : sim
sim : dir
	$(call ACTION_HEADER,"VCS Simulation")
	@rm -rf $(SIM_DIR); mkdir $(SIM_DIR);
	@cd $(SIM_DIR); source $(RUCKUS_GENUS_DIR)/sim.sh

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
