##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Vivado-free Icarus Verilog simulation flow. Loads a project's ruckus.tcl
# tree with no Vivado, compiles with iverilog -g2012 and runs with vvp.
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
export RUCKUS_IVERILOG_DIR = $(RUCKUS_DIR)/iverilog
export RUCKUS_PROC_TCL = $(RUCKUS_IVERILOG_DIR)/proc.tcl

# Rogue co-simulation backend for surf/axi/simlink/ruckus.tcl
ifndef RUCKUS_SIM_BACKEND
export RUCKUS_SIM_BACKEND = iverilog
endif

# Project Build Directory
ifndef OUT_DIR
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))
endif

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Top-level module simulated by vvp
ifndef SIM_TOP
export SIM_TOP = $(PROJECT)
endif

# Icarus Verilog compile flags
ifndef IVERILOG_FLAGS
export IVERILOG_FLAGS = -g2012
endif

# vvp run flags
ifndef VVP_FLAGS
export VVP_FLAGS = -n
endif

# VERILOG_INCDIRS, VERILOG_DEFINES (words "NAME" or "NAME=VAL"), SIM_PLUSARGS
# and WAVES all default to empty. Project Makefiles override any of these
# before the include line, as with GHDLFLAGS.

# Legacy Vivado Version: surf/simlink/ruckus.tcl reads this unconditionally
export VIVADO_VERSION = -1.0

# Derived Icarus Verilog include/define flags (not exported)
IVERILOG_INC_DEF = $(addprefix -I,$(abspath $(VERILOG_INCDIRS))) $(addprefix -D,$(VERILOG_DEFINES))

# Derived vvp waveform flag (not exported)
VVP_WAVES = $(if $(filter 1,$(WAVES)),-fst)

###############################################################

include $(RUCKUS_DIR)/system_shared.mk

# Override system_shared.mk build string
export IVERILOG_VERSION = $(shell iverilog -V 2>/dev/null | head -n 1)
export BUILD_STRING   = $(PROJECT): $(IVERILOG_VERSION), ${BUILD_SYS_NAME} (${BUILD_SVR_TYPE}), Built ${BUILD_DATE} by ${BUILD_USER}

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
	@echo RUCKUS_SIM_BACKEND: $(RUCKUS_SIM_BACKEND)
	@echo OUT_DIR: $(OUT_DIR)
	@echo SIM_TOP: $(SIM_TOP)
	@echo IVERILOG_FLAGS: $(IVERILOG_FLAGS)
	@echo VVP_FLAGS: $(VVP_FLAGS)
	@echo VERILOG_INCDIRS: $(VERILOG_INCDIRS)
	@echo VERILOG_DEFINES: $(VERILOG_DEFINES)
	@echo SIM_PLUSARGS: $(SIM_PLUSARGS)
	@echo WAVES: $(WAVES)
	@echo GIT_BYPASS: $(GIT_BYPASS)
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
	$(call ACTION_HEADER,"Icarus Verilog: Load the Source Code")
	@$(RUCKUS_IVERILOG_DIR)/load_source_code.tcl

###############################################################
#### Build   ##################################################
###############################################################
.PHONY : build
build : load_source_code
	$(call ACTION_HEADER,"Icarus Verilog: build (iverilog)")
	@$(RUCKUS_IVERILOG_DIR)/simlink.tcl
	@echo iverilog $(IVERILOG_FLAGS) $(IVERILOG_INC_DEF) -s $(SIM_TOP) -o $(SIM_TOP).vvp -c $(PROJECT).f
	@cd $(OUT_DIR); iverilog $(IVERILOG_FLAGS) $(IVERILOG_INC_DEF) -s $(SIM_TOP) -o $(SIM_TOP).vvp -c $(PROJECT).f

###############################################################
#### Run     ###################################################
###############################################################
.PHONY : tb
tb : build
	$(call ACTION_HEADER,"Icarus Verilog: run (vvp)")
	@cd $(OUT_DIR); \
	if [ -f RogueSimLink.vpi ]; then set -- -M$(OUT_DIR) -mRogueSimLink; fi; \
	echo vvp $(VVP_FLAGS) "$$@" $(SIM_TOP).vvp $(VVP_WAVES) $(SIM_PLUSARGS); \
	vvp $(VVP_FLAGS) "$$@" $(SIM_TOP).vvp $(VVP_WAVES) $(SIM_PLUSARGS)

###############################################################
#### gtkwave   ##################################################
###############################################################
.PHONY : gtkwave
gtkwave : WAVES = 1
gtkwave : tb
	$(call ACTION_HEADER,"Icarus Verilog: gtkwave $(PROJECT).fst")
	@cd $(OUT_DIR); gtkwave $(PROJECT).fst

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
