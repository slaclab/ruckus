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

ifndef FAB_ROOT
export FAB_ROOT = $(TOP_DIR)/submodules/FABulous
endif

# Specifies the synthesis type [verilog, vhdl]
ifndef HDL_TYPE
export HDL_TYPE = verilog
endif

ifndef PYFAB
export PYFAB = $(FAB_ROOT)/FABulous.py -w $(HDL_TYPE)
endif

ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export RUCKUS_FAB_DIR    = $(RUCKUS_DIR)/fabulous
export RUCKUS_PROC_TCL   = $(RUCKUS_FAB_DIR)/proc.tcl
export RUCKUS_QUIET_FLAG = -verbose

# Project Build Directory
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# HDL Directory
export HDL_DIR = $(abspath $(PROJ_DIR)/hdl_output)

###############################################################

include $(TOP_DIR)/submodules/ruckus/system_shared.mk

# Software Package Versions
export FAB_VERSION     = $(shell git submodule | grep FABulous | sed 's/.*(//; s/).*//')
export YOSYS_VERSION   = $(shell yosys -V | sed 's/.*Yosys //; s/ .*//')
export VIVADO_VERSION  = -1.0

# Override system_shared.mk build string
export BUILD_STRING = $(PROJECT): $(FAB_VERSION), $(BUILD_SYS_NAME) ($(BUILD_SVR_TYPE)), Built $(BUILD_DATE) by $(BUILD_USER)

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
	@echo BUILD_STRING: $${BUILD_STRING}
	@echo FAB_ROOT: $(FAB_ROOT)
	@echo HDL_TYPE: $(HDL_TYPE)
	@echo PYFAB: $(PYFAB)
	@echo FAB_VERSION: $(FAB_VERSION)
	@echo YOSYS_VERSION: $(YOSYS_VERSION)
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
	@test -f $(PROJ_DIR)/fabric.csv || { \
			 echo ""; \
			 echo "$(PROJ_DIR)/fabric.csv missing!"; \
			 echo ""; false; }
	@rm -rf $(OUT_DIR)

###############################################################
#### Create Project ###########################################
###############################################################
.PHONY : proj
proj: dir
	$(call ACTION_HEADER,"Fabulous: Create Project")
	@cd $(TOP_DIR)/build; python3 $(PYFAB) -c $(PROJECT)
	@cp -f $(PROJ_DIR)/fabric.csv $(OUT_DIR)/.

###############################################################
#### Generate the bitstream ###################################
###############################################################
.PHONY : bin
bin: proj
	$(call ACTION_HEADER,"Fabulous: Generate the bitstream")
	@cd $(TOP_DIR)/build; export DUMP_HDL=0; python3 $(PYFAB) -s $(RUCKUS_FAB_DIR)/build.tcl $(PROJECT)

###############################################################
#### Generate the eFPGA fabric ################################
###############################################################
.PHONY : fabric
fabric: proj
	$(call ACTION_HEADER,"Fabulous: Generate the eFPGA fabric")
	@cd $(TOP_DIR)/build; export DUMP_HDL=1; python3 $(PYFAB) -s $(RUCKUS_FAB_DIR)/build.tcl $(PROJECT)

###############################################################
#### Interactive Mode   #######################################
###############################################################
.PHONY : interactive
interactive : proj
	$(call ACTION_HEADER,"Fabulous Interactive")
	@cd $(TOP_DIR)/build; python3 $(PYFAB) $(PROJECT)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
