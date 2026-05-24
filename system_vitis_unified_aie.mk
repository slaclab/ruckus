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

# Standard ruckus layout assumes the consumer Makefile lives at
# firmware/<category>/<name>/Makefile (firmware/shared/<name>/ for shared
# archetypes, firmware/targets/<name>/ for Vivado targets). $(PWD)/../..
# resolves to firmware/, where submodules/ruckus lives. Override
# TOP_DIR before include if you have a non-standard layout.
ifndef TOP_DIR
export TOP_DIR = $(abspath $(PWD)/../..)
endif

# Project Build Directory ("workspace")
ifndef OUT_DIR
export OUT_DIR = $(PROJ_DIR)/build
endif

# Synthesis Variables
# VIVADO_VERSION feeds BUILD_STRING in system_shared.mk ("Vivado v...").
export VIVADO_VERSION  := $(shell vivado -version | grep -Po "v(\d+\.)+\d+" | cut -c2-)
export RUCKUS_DIR       = $(TOP_DIR)/submodules/ruckus

##############################################################################
## Hard-fail early if the environment was not sourced. Vitis 2025.1 minimum
## is required for the AIE Python API used by vitis/aie/{create_proj,build}.py.
##############################################################################
ifndef XILINX_VITIS
$(error XILINX_VITIS not set — source firmware/setup_env_slac.sh first)
endif

include $(TOP_DIR)/submodules/ruckus/system_shared.mk

##############################################################################
## Required caller-defined variables. All five must be set in the consuming
## target's AIE Makefile before including this file.
##############################################################################
##############################################################################
## Exactly one of AIE_PLATFORM (xpfm path) or AIE_PART (Versal device ID)
## must be defined. Use AIE_PLATFORM for dev boards with an AMD-shipped
## .xpfm (e.g. xilinx_vek280_base_*); use AIE_PART for custom Versal AIE
## boards that don't ship an xpfm. Both define the AIE array geometry;
## AIE_PLATFORM additionally carries platform-specific data (PL clock caps,
## NoC config, AIE-PL interface constraints), while AIE_PART relies on the
## cfg's pl-freq= for the PL clock hint.
##############################################################################
ifeq ($(strip $(AIE_PLATFORM)$(AIE_PART)),)
$(error Define either AIE_PLATFORM (.xpfm path, e.g. $$(XILINX_VITIS)/base_platforms/<board>/<board>.xpfm) or AIE_PART (Versal device ID, e.g. xcve2802-vsvh1760-2MP-e-S) in the target's AIE Makefile)
endif
ifneq ($(and $(strip $(AIE_PLATFORM)),$(strip $(AIE_PART))),)
$(error Define only one of AIE_PLATFORM or AIE_PART, not both — use AIE_PLATFORM for dev boards with a shipped .xpfm, AIE_PART for custom boards without one)
endif

ifndef AIE_SOURCES
$(error AIE_SOURCES not set — define it in the target's AIE Makefile as a whitespace-separated list of `path[:dest_subdir]` entries. File entries import that one file; directory entries import every .cpp/.cc/.h/.hpp file in the directory (non-recursive). Without `:dest_subdir`, files land flat at the component root; with `:dest_subdir`, they import into <component>/<dest_subdir>/ (matches the AMD-canonical `kernels/` layout where graph.h does `adf::source(loop) = "kernels/loopback.cc";`). e.g. AIE_SOURCES = $$(CURDIR)/aie $$(CURDIR)/aie/kernels:kernels $$(TOP_DIR)/submodules/aie-lib/util.cc)
endif

ifndef AIE_TOP_LEVEL_FILE
$(error AIE_TOP_LEVEL_FILE not set — define it in the target's AIE Makefile (e.g. AIE_TOP_LEVEL_FILE = graph.cpp))
endif

##############################################################################
## AIE_XSA_INPUT is required by the package step (not by proj/build/clean/gui).
## It must be supplied by the caller at the command line because the Vivado-side
## IMAGENAME embeds $(BUILD_TIME), so the .xsa filename produced by an
## earlier `make pdi` in the upstream Vivado target is not predictable from
## within this AIE archetype's make invocation. Asserted at recipe-time inside
## `package` so that clean/gui/proj/build/x86sim/interactive/test do not require it.
##############################################################################
## Derived / packaging-related paths. Mirrors the HLS convention of writing
## the final deliverable to $(PROJ_DIR)/ip/, keeping the AIE archetype
## self-contained and decoupled from any consuming Vivado target.
##############################################################################
ifndef AIE_PKG_DIR
export AIE_PKG_DIR = $(OUT_DIR)/aie_package
endif

ifndef AIE_IP_DIR
export AIE_IP_DIR = $(PROJ_DIR)/ip
endif

ifndef AIE_PDI
export AIE_PDI = $(AIE_IP_DIR)/$(PROJECT)_aie_dynamic.pdi
endif

ifndef VPP_LOG
export VPP_LOG = $(OUT_DIR)/vpp_package.log
endif

ifndef USE_BOOTGEN_FALLBACK
export USE_BOOTGEN_FALLBACK = 0
endif

# AIE_PROGRAM_SCRIPT — helper invoked by `make program` to deploy AIE_PDI
# to the board. Defaults to the ruckus-shipped vitis/aie/program.sh, which
# is a generic Versal/PetaLinux deploy (scp PDI+DTBO → /boot/, reboot, verify
# fpga_manager state). Override if your project needs richer verification
# (e.g. application-specific systemd checks, xsdb readout, etc.). The helper
# must accept:
#     -p <pdi-path>    runtime PDI to upload
#     -d <dtbo-path>   matching device-tree overlay
#     -i <user@ip>     board target
ifndef AIE_PROGRAM_SCRIPT
export AIE_PROGRAM_SCRIPT = $(RUCKUS_DIR)/vitis/aie/program.sh
endif

.PHONY : all
all: target

###############################################################
#### Printout Env. Variables ##################################
###############################################################
.PHONY : test
test:
	@echo VIVADO_VERSION:    $(VIVADO_VERSION)
	@echo PROJECT:           $(PROJECT)
	@echo PROJ_DIR:          $(PROJ_DIR)
	@echo TOP_DIR:           $(TOP_DIR)
	@echo OUT_DIR:           $(OUT_DIR)
	@echo RUCKUS_DIR:        $(RUCKUS_DIR)
	@echo AIE_PLATFORM:      $(AIE_PLATFORM)
	@echo AIE_PART:          $(AIE_PART)
	@echo AIE_SOURCES:       $(AIE_SOURCES)
	@echo AIE_TOP_LEVEL_FILE:$(AIE_TOP_LEVEL_FILE)
	@echo AIE_XSA_INPUT:     $(AIE_XSA_INPUT)

###############################################################
#### Project Creation #########################################
###############################################################
.PHONY : proj
proj:
	$(call ACTION_HEADER,"Vitis AIE Create Project")
	@test -d $(OUT_DIR) || mkdir -p $(OUT_DIR)
	@cd $(OUT_DIR); vitis -s $(RUCKUS_DIR)/vitis/aie/create_proj.py

###############################################################
#### Vitis AIE Batch Build (hw target) ########################
###############################################################
.PHONY : build
build : proj
	$(call ACTION_HEADER,"Vitis AIE Build (target=hw)")
	@cd $(OUT_DIR); vitis -s $(RUCKUS_DIR)/vitis/aie/build.py

###############################################################
#### Vitis AIE x86 Simulation Build ###########################
###############################################################
.PHONY : x86sim
x86sim : proj
	$(call ACTION_HEADER,"Vitis AIE x86sim")
	@cd $(OUT_DIR); vitis -s $(RUCKUS_DIR)/vitis/aie/build.py --x86sim

###############################################################
#### Package — wraps libadf.a + XSA into dynamic PDI ##########
###############################################################
.PHONY : package
package : build
	$(call ACTION_HEADER,"Vitis AIE Package")
	@if [ -z "$(AIE_XSA_INPUT)" ]; then \
	  echo "ERROR: AIE_XSA_INPUT not set — pass the absolute path to the Vivado-built .xsa,"; \
	  echo "       e.g. make AIE_XSA_INPUT=<path>/<image>.xsa package"; \
	  exit 1; \
	fi
	@bash $(RUCKUS_DIR)/vitis/aie/package.sh

###############################################################
#### program — deploy AIE_PDI to the target board #############
###############################################################
# Wraps $(AIE_PROGRAM_SCRIPT) — defaults to ruckus's vitis/aie/program.sh,
# overridable per project. Caller must pass AIE_DTBO=<path> on the command
# line. AIE_BOARD_IP is forwarded as `-i` if set. Asserts are recipe-time
# (not parse-time) so other targets aren't affected.
.PHONY : program
program:
	$(call ACTION_HEADER,"Vitis AIE Program")
	@if [ ! -r "$(AIE_PROGRAM_SCRIPT)" ]; then \
	  echo "ERROR: AIE_PROGRAM_SCRIPT '$(AIE_PROGRAM_SCRIPT)' not found."; \
	  echo "       Override AIE_PROGRAM_SCRIPT to point at your deploy helper."; \
	  exit 1; \
	fi
	@if [ -z "$(AIE_DTBO)" ]; then \
	  echo "ERROR: AIE_DTBO not set — pass the absolute path to the matching .dtbo."; \
	  echo "       e.g. make AIE_DTBO=<vivado-target>/images/<name>.dtbo program"; \
	  exit 1; \
	fi
	bash $(AIE_PROGRAM_SCRIPT) \
	  -p $(AIE_PDI) \
	  -d $(AIE_DTBO) \
	  $(if $(AIE_BOARD_IP),-i $(AIE_BOARD_IP),)

###############################################################
#### Vitis AIE Interactive ####################################
###############################################################
.PHONY : interactive
interactive : proj
	$(call ACTION_HEADER,"Vitis AIE Interactive")
	@cd $(OUT_DIR); vitis -i

###############################################################
#### Vitis AIE GUI ############################################
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
