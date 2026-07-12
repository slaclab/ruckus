##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# ----------------------------------------------------------------------------
# `make` front-end for the hlsBs build system.
#
# A target is steered by a single project descriptor:
#     firmware/targets/<Name>/project/<Name>.py
# built over the shared, reusable hlsBs engine in the ruckus submodule
# (vitis/hlsBs). This mirrors the Vitis-Unified-CLI flow
# (system_vitis_unified_hls.mk, steered by hls_config.cfg) so a target can be
# built with plain `make` instead of the hlsWs/hlsCfg/hlsRun command sequence.
#
# The hls* commands are bash functions defined in
# vitis/hlsBs/scripts/setup_hls.sh; each recipe sources that script, selects the
# Vitis version, then invokes the function. `source firmware/setup_env_slac.sh`
# (which puts vitis/vivado + XILINX_HLS on PATH) BEFORE running make.
# ----------------------------------------------------------------------------

# hls* entry points are bash functions -> recipes must use bash, not sh
SHELL := /bin/bash

# Define project name (defaults to the target directory name). This becomes the
# hlsBs build/component/IP name, keeping directory == component == IP aligned.
ifndef PROJECT
export PROJECT = $(notdir $(PWD))
endif

# Define project path
ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

# Location of the reusable ruckus engine
export RUCKUS_DIR = $(TOP_DIR)/submodules/ruckus

# hlsBs shell entry points and the project descriptor for THIS target.
# HLSBS_PROJECT is consumed by the hls* functions (via hlsPrj -> --project=).
HLSBS_SETUP          = $(RUCKUS_DIR)/vitis/hlsBs/scripts/setup_hls.sh
export HLSBS_PROJECT = $(PROJ_DIR)/project/$(PROJECT).py

# Vitis version. Empty => auto-detect from the already-sourced Vitis
# (source firmware/setup_env_slac.sh first). Override: `make VITIS_VERSION=2025.1`
# (requires HLSBS_XILINX_SETUP; see firmware/setup_env_slac.sh).
VITIS_VERSION ?=

# Bootstrap hlsBs inside the recipe shell: load the functions + select the
# version (sets $hlsPython, HLSBS_LD_LIBRARY_PATH, HLSBS_IMPORT_PYPATHS, ...).
# Every recipe that calls an hls* function must run this first, in the SAME shell.
BOOT = source $(HLSBS_SETUP) && hlsVersion $(VITIS_VERSION)

.PHONY : all target proj build csim gui interactive clean test

all : target

###############################################################
#### Create workspace + configuration/component ###############
###############################################################
# Idempotent: the workspace is created only if it does not already exist
# (hlsWs --status), and hlsCfg --create only creates missing components.
.PHONY : proj
proj:
	@echo "------------------------------------------------------"
	@echo " hlsBs : create workspace + configuration [$(PROJECT)]"
	@echo "------------------------------------------------------"
	@$(BOOT) && { hlsWs --status > /dev/null 2>&1 || hlsWs --create; } && hlsCfg --create

###############################################################
#### Full HLS flow (csim->synth->cosim->package->impl->ip) ####
###############################################################
.PHONY : build
build : proj
	@echo "------------------------------------------------------"
	@echo " hlsBs : build [$(PROJECT)] -> ip/$(PROJECT).{zip,dcp}"
	@echo "------------------------------------------------------"
	@$(BOOT) && hlsRun --all

###############################################################
#### Fast algorithm check: compile + run the C testbench ######
###############################################################
.PHONY : csim
csim : proj
	@$(BOOT) && hlsRun --csim=m,r

###############################################################
#### Open the Vitis Unified IDE on the workspace ##############
###############################################################
.PHONY : gui
gui : proj
	@$(BOOT) && hlsGui

###############################################################
#### Open an interactive Vitis shell ##########################
###############################################################
.PHONY : interactive
interactive : proj
	@$(BOOT) && vitis -i

###############################################################
#### Clean (remove workspace + generated cfg; keeps ip) #######
###############################################################
# No Vitis tools required: build/ (the Vitis workspace + generated cfg) and .Xil/
# (vivado scratch dir) are just directories. The packaged IP in ip/ is preserved.
.PHONY : clean
clean:
	rm -rf $(PROJ_DIR)/build $(PROJ_DIR)/.Xil

###############################################################
#### Printout resolved env. variables (no tools required) #####
###############################################################
.PHONY : test
test:
	@echo "PROJECT       : $(PROJECT)"
	@echo "PROJ_DIR      : $(PROJ_DIR)"
	@echo "TOP_DIR       : $(TOP_DIR)"
	@echo "RUCKUS_DIR    : $(RUCKUS_DIR)"
	@echo "HLSBS_SETUP   : $(HLSBS_SETUP)"
	@echo "HLSBS_PROJECT : $(HLSBS_PROJECT)"
	@echo "VITIS_VERSION : '$(VITIS_VERSION)' (empty => auto-detect from sourced Vitis)"
