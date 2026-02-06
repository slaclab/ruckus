##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# https://umarcor.github.io/ghdl/using/InvokingGHDL.html
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

# Define the top-level VHDL lib
ifndef GHDL_TOP_LIB
export GHDL_TOP_LIB = work
endif

# Define the default stop time
ifndef GHDL_STOP_TIME
export GHDL_STOP_TIME = 10ns
endif

# Create the simulation testbed run args
export GHDL_RUN_ARGS = $(GHDLFLAGS) -P$(OUT_DIR) --work=$(GHDL_TOP_LIB) $(PROJECT) --wave=$(PROJECT).ghw --stop-time=$(GHDL_STOP_TIME)

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
	@echo GHDL_TOP_LIB: $(GHDL_TOP_LIB)
	@echo GHDL_STOP_TIME: $(GHDL_STOP_TIME)
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
	@test -d $(OUT_DIR)    || mkdir $(OUT_DIR)
	@test -d $(IMAGES_DIR) || mkdir $(IMAGES_DIR)

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
#### Elab-order ###############################################
###############################################################
.PHONY : elab_order
elab_order : import
	$(call ACTION_HEADER,"GHDL: Elab-order (ghdl --elab-order)")
	@echo ghdl --elab-order $(GHDLFLAGS) -P$(OUT_DIR) --work=$(GHDL_TOP_LIB) $(PROJECT)
	@cd $(OUT_DIR); ghdl --elab-order $(GHDLFLAGS) -P$(OUT_DIR) --work=$(GHDL_TOP_LIB) $(PROJECT)

###############################################################
#### Build   ##################################################
###############################################################
.PHONY : build
build : elab_order
	$(call ACTION_HEADER,"GHDL: build (ghdl -m)")
	@echo ghdl -m $(GHDLFLAGS) -P$(OUT_DIR) --work=$(GHDL_TOP_LIB) $(PROJECT)
	@cd $(OUT_DIR); ghdl -m $(GHDLFLAGS) -P$(OUT_DIR) --work=$(GHDL_TOP_LIB) $(PROJECT) 2>&1 | tee $(OUT_DIR)/$(PROJECT).elab_order
	@sed -e '/^elaborate[[:space:]]/,$$d' \
	     -e 's/^analyze[[:space:]]\+//' \
	     $(OUT_DIR)/$(PROJECT).elab_order \
	     > $(IMAGES_DIR)/$(PROJECT).elab_order

###############################################################
#### Build   ##################################################
###############################################################
.PHONY : tb
tb : build
	$(call ACTION_HEADER,"GHDL: build (ghdl -r)")
	@echo ghdl -r $(GHDL_RUN_ARGS)> >(grep -v "std_logic_arith.vhdl")
	@cd $(OUT_DIR); ghdl -r $(GHDL_RUN_ARGS)> >(grep -v "std_logic_arith.vhdl")

###############################################################
#### gtkwave   ##################################################
###############################################################
.PHONY : gtkwave
gtkwave : tb
	$(call ACTION_HEADER,"GHDL: gtkwave $(PROJECT).ghw")
	@cd $(OUT_DIR); gtkwave $(PROJECT).ghw

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
	@ghdl -e $(GHDLFLAGS) -P$(OUT_DIR) --work=$(GHDL_TOP_LIB) $(PROJECT)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
