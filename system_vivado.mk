##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

ifndef PROJECT
export PROJECT = $(notdir $(PWD))
endif

ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

ifndef TOP_DIR
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)
endif

ifndef RELEASE_DIR
export RELEASE_DIR = $(TOP_DIR)/release
endif

ifndef MODULES
export MODULES = $(TOP_DIR)/submodules
endif

ifndef REMOVE_UNUSED_CODE
export REMOVE_UNUSED_CODE = 0
endif

ifndef PARALLEL_SYNTH
export PARALLEL_SYNTH := $(shell cat /proc/cpuinfo | grep processor | wc -l)
endif

ifndef GIT_BYPASS
export GIT_BYPASS = 1
endif

ifndef REPORT_QOR
export REPORT_QOR = 0
endif

##############################################################################

ifndef GEN_BIT_IMAGE
export GEN_BIT_IMAGE = 1
endif

ifndef GEN_BIT_IMAGE_GZIP
export GEN_BIT_IMAGE_GZIP = 0
endif

ifndef GEN_BIN_IMAGE
export GEN_BIN_IMAGE = 0
endif

ifndef GEN_BIN_IMAGE_GZIP
export GEN_BIN_IMAGE_GZIP = 0
endif

ifndef GEN_PDI_IMAGE
export GEN_PDI_IMAGE = 1
endif

ifndef GEN_PDI_IMAGE_GZIP
export GEN_PDI_IMAGE_GZIP = 0
endif

ifndef GEN_MCS_IMAGE
export GEN_MCS_IMAGE = 1
endif

ifndef GEN_MCS_IMAGE_GZIP
export GEN_MCS_IMAGE_GZIP = 0
endif

ifndef GEN_XSA_IMAGE
export GEN_XSA_IMAGE = 0
endif

##############################################################################

ifndef RECONFIG_CHECKPOINT
export RECONFIG_CHECKPOINT = 0
export RECONFIG_STATIC_HASH = 0
else
export RECONFIG_STATIC_FILE = $(notdir $(RECONFIG_CHECKPOINT))
export RECONFIG_STATIC_HASH = $(shell echo '$(RECONFIG_STATIC_FILE)' | awk -F'-' '{print $$5}' )
endif

ifndef RECONFIG_ENDPOINT
export RECONFIG_ENDPOINT = 0
endif

ifndef RECONFIG_PBLOCK
export RECONFIG_PBLOCK = 0
endif

# Versal Segmented Configuration Variables
ifndef USE_SEGMENTED_CONFIG
export USE_SEGMENTED_CONFIG = 0
endif

# Vivado Simulation Variables
# When left undefined, the sim_1 top is auto-picked-up from the project
# (i.e. the "set_property top ... [get_filesets sim_1]" in the target's
# ruckus.tcl). Define VIVADO_PROJECT_SIM only to override that top.
ifndef VIVADO_PROJECT_SIM
export VIVADO_PROJECT_SIM =
endif
# Default sim run length. "all" runs until the testbench calls finish/stop or
# is interrupted; a time value (e.g. "1000 ns") runs that long. Testbenches
# without a finish/stop free-run under "all", so a batch "make xsim" there must
# be stopped manually.
ifndef VIVADO_PROJECT_SIM_TIME
export VIVADO_PROJECT_SIM_TIME = all
endif

# Synthesis Variables
export VIVADO_VERSION  := $(shell vivado -version | grep -Po "v(\d+\.)+\d+" | cut -c2-)
export VIVADO_INSTALL  := $(abspath  $(shell which vivado)/../..)
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(VIVADO_PROJECT).xpr
ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export SOURCE_DEPEND     = $(OUT_DIR)/$(PROJECT)_sources.txt
export RUCKUS_PROC_TCL   = $(RUCKUS_DIR)/vivado/proc.tcl
export RUCKUS_QUIET_FLAG = -quiet

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Project Build Directory
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
export SYN_DIR  = $(OUT_DIR)/$(VIVADO_PROJECT).runs/synth_1
export IMPL_DIR = $(OUT_DIR)/$(VIVADO_PROJECT).runs/impl_1

# Define the user IP repo
ifndef IP_REPO
export IP_REPO = $(OUT_DIR)/ip_repo
endif

# Workaround for "[Common 17-356] Failed to install all user apps" error message
# https://adaptivesupport.amd.com/s/question/0D52E00006iHp31SAC/synthesis-errors-common-17354-could-not-open-c-for-writing-common-17356-failed-to-install-all-user-apps
ifndef XILINX_LOCAL_USER_DATA
export XILINX_LOCAL_USER_DATA = no
endif

ifndef VIVADO_GUI_JAVA_MEM
export VIVADO_GUI_JAVA_MEM =
endif

###############################################################

ifndef SIM_CARGS_VERILOG
export SIM_CARGS_VERILOG = -nc -l +v2k -xlrm -kdb -v2005 +define+SIM_SPEED_UP
endif

ifndef SIM_CARGS_VHDL
export SIM_CARGS_VHDL = -nc -l +v2k -xlrm -kdb
endif

ifndef SIM_VCS_FLAGS
export SIM_VCS_FLAGS = -debug_acc+pp+dmptf +warn=none -kdb -lca
endif

###############################################################
#           Vitis Variables (Vivado 2019.2 or newer)
###############################################################

export VITIS_PRJ = $(abspath $(OUT_DIR)/$(VIVADO_PROJECT).vitis)
export VITIS_ELF = $(abspath $(VITIS_PRJ)/$(PROJECT).elf)

ifdef SDK_LIB
   export VITIS_LIB = $(SDK_LIB)
else
   ifndef VITIS_LIB
      export VITIS_LIB = $(MODULES)/surf/xilinx/general/sdk/common
   endif
endif

# Check if SDK_SRC_PATH defined but VITIS_SRC_PATH not (legacy support)
ifdef SDK_SRC_PATH
   ifndef VITIS_SRC_PATH
      export VITIS_SRC_PATH = $(SDK_SRC_PATH)
   endif
endif

###############################################################
#           SDK Variables (Vivado 2019.1 or older)
###############################################################

export SDK_PRJ = $(abspath $(OUT_DIR)/$(VIVADO_PROJECT).sdk)
export SDK_ELF = $(abspath $(SDK_PRJ)/$(PROJECT).elf)

ifndef SDK_LIB
export SDK_LIB  =  $(MODULES)/surf/xilinx/general/sdk/common
endif

###############################################################

ifndef EMBED_PROC
export EMBED_PROC = microblaze_0
endif

# True when VIVADO_VERSION >= 2026.1 (Vitis dropped the Eclipse GUI/XSCT for the Unified IDE)
VIVADO_GE_2026_1 := $(shell printf '2026.1\n%s\n' "$(VIVADO_VERSION)" | sort -V 2>/dev/null | head -n1)

ifneq (, $(shell which vitis 2>/dev/null))
   export EMBED_TYPE = Vitis
   ifeq ($(VIVADO_GE_2026_1),2026.1)
      # Vitis 2026.1 (or newer): Unified IDE launch syntax
      export EMBED_GUI  = vitis -w $(OUT_DIR)/$(VIVADO_PROJECT).vitis
   else
      # Vitis 2019.2 .. 2025.x: legacy Eclipse-based GUI
      export EMBED_GUI  = vitis -workspace $(OUT_DIR)/$(VIVADO_PROJECT).vitis -vmargs -Dorg.eclipse.swt.internal.gtk.cairoGraphics=false
   endif
   export EMBED_ELF  = vivado -mode batch -source $(RUCKUS_DIR)/MicroblazeBasicCore/vitis/bit.tcl
else
   export EMBED_TYPE = SDK
   export EMBED_GUI  = xsdk -workspace $(OUT_DIR)/$(VIVADO_PROJECT).sdk -vmargs -Dorg.eclipse.swt.internal.gtk.cairoGraphics=false
   export EMBED_ELF  = vivado -mode batch -source $(RUCKUS_DIR)/MicroblazeBasicCore/sdk/bit.tcl

   ifndef LD_PRELOAD
   export LD_PRELOAD =
   endif

   # Ubuntu SDK support
   ifndef SWT_GTK3
   export SWT_GTK3 = 0
   endif

endif

define COPY_PROBES_FILE
@if [ -f '$(OUT_DIR)/debugProbes.ltx' ] ; then \
	$(RM) '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	cp '$(OUT_DIR)/debugProbes.ltx' '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	echo "Debug Probes file copied to $(IMAGES_DIR)/$(IMAGENAME).ltx "; \
elif  [ -f '$(IMPL_DIR)/debug_nets.ltx' ] ; then \
	$(RM) '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	cp '$(IMPL_DIR)/debug_nets.ltx' '$(IMAGES_DIR)/$(IMAGENAME).ltx' ; \
	echo "Debug Probes file copied to $(IMAGES_DIR)/$(IMAGENAME).ltx "; \
else \
	echo "No Debug Probes found"; \
fi
endef

include $(MODULES)/ruckus/system_shared.mk

.PHONY : all
all: target

###############################################################
#### Printout Environmental Variables #########################
###############################################################

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo PRJ_VERSION: $(PRJ_VERSION)
	@echo PRJ_PART: $(PRJ_PART)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo IMAGES_DIR: $(IMAGES_DIR)
	@echo IMPL_DIR: $(IMPL_DIR)
	@echo VIVADO_DIR: $(VIVADO_DIR)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo VIVADO_PROJECT: $(VIVADO_PROJECT)
	@echo VIVADO_VERSION: $(VIVADO_VERSION)
	@echo VIVADO_INSTALL: $(VIVADO_INSTALL)
	@echo VIVADO_GUI_JAVA_MEM: $(VIVADO_GUI_JAVA_MEM)
	@echo XILINX_LOCAL_USER_DATA: $(XILINX_LOCAL_USER_DATA)
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)
	@echo IMAGENAME: $(IMAGENAME)
	@echo BUILD_STRING: $${BUILD_STRING}
	@echo EMBED_PROC: $(EMBED_PROC)
	@echo EMBED_TYPE: $(EMBED_TYPE)
	@echo EMBED_GUI: $(EMBED_GUI)
	@echo EMBED_ELF: $(EMBED_ELF)
	@echo Untracked Files:
	@echo "${GIT_STATUS}" | sed -e 's/ /\n/g'

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
	@test -d $(OUT_DIR)     || mkdir $(OUT_DIR)
	@test -d $(RELEASE_DIR) || mkdir $(RELEASE_DIR)
	@test -d $(IP_REPO)     || mkdir $(IP_REPO)

###############################################################
#### Vivado Sources ###########################################
###############################################################
$(SOURCE_DEPEND) : dir
	$(call ACTION_HEADER,"Vivado Source Setup")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado/sources.tcl

###############################################################
#### Vivado Project GUI mode ##################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Project GUI Mode")
	@cd $(OUT_DIR); vivado $(VIVADO_GUI_JAVA_MEM) -source $(RUCKUS_DIR)/vivado/gui.tcl $(VIVADO_PROJECT).xpr

###############################################################
#### Vivado Batch #############################################
###############################################################
.PHONY : bit mcs prom pdi
bit mcs prom pdi : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Batch Build for .bit/.mcs")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado/build.tcl

###############################################################
#### Vivado Synthesis Only ####################################
###############################################################
.PHONY : syn
syn : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis Only")
	@cd $(OUT_DIR); export SYNTH_ONLY=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado/build.tcl

###############################################################
#### Vivado Synthesis DCP  ####################################
###############################################################
.PHONY : dcp
dcp : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis DCP")
	@cd $(OUT_DIR); export SYNTH_DCP=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado/build.tcl

###############################################################
#### Vivado Interactive #######################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Interactive")
	@cd $(OUT_DIR); vivado -mode tcl -source $(RUCKUS_DIR)/vivado/env_var.tcl

###############################################################
#### Vivado SDK ###############################################
###############################################################
.PHONY : sdk vitis
sdk vitis :
	$(call ACTION_HEADER,"Vivado $(EMBED_TYPE) GUI")
	@cd $(OUT_DIR); $(EMBED_GUI)

###############################################################
#### Vivado SDK ELF ###########################################
###############################################################
.PHONY : elf
elf :
	$(call ACTION_HEADER,"Vivado $(EMBED_TYPE) .ELF generation")
	@cd $(OUT_DIR); $(EMBED_ELF)
	@echo ""
	@echo "Bit file w/ Elf file copied to $(IMAGES_DIR)/$(IMAGENAME).bit"

###############################################################
#### Release ##################################################
###############################################################
.PHONY : release
# Hand the credential back to this target only, from the stash system_shared.mk kept.
# Target-specific export, not an inline GITHUB_TOKEN=... prefix, so the value stays out
# of the shell's argv where "ps" would show it. Without the ifdef, an absent token would
# export as "" and firmwareRelease.py would authenticate with it instead of prompting.
ifdef RUCKUS_GITHUB_AUTH
release : export GITHUB_TOKEN := $(RUCKUS_GITHUB_AUTH)
endif
release : dir
	$(call ACTION_HEADER,"Generating Release")
	@cd $(RELEASE_DIR); python3 $(RUCKUS_DIR)/scripts/firmwareRelease.py --project=$(TOP_DIR) --release=$(RELEASE) --push

###############################################################
#### Release Files ############################################
###############################################################
.PHONY : release_files
release_files : dir
	$(call ACTION_HEADER,"Generating Release Files")
	@cd $(RELEASE_DIR); python3 $(RUCKUS_DIR)/scripts/firmwareRelease.py --project=$(TOP_DIR) --release=$(RELEASE)

###############################################################
#### Vivado PyRogue ###########################################
###############################################################
.PHONY : pyrogue
pyrogue : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generating pyrogue.tar.gz file")
	@cd $(OUT_DIR); tclsh $(RUCKUS_DIR)/vivado/pyrogue.tcl

###############################################################
#### Vivado CPSW ##############################################
###############################################################
.PHONY : yaml
yaml : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generating cpsw.tar.gz file")
	@cd $(OUT_DIR); tclsh $(RUCKUS_DIR)/vivado/cpsw.tcl

###############################################################
#### Rogue Co-Simulation Backend ##############################
###############################################################
# Tell surf/axi/simlink/ruckus.tcl which Rogue co-sim backend the invoked
# target wants. Target-specific + exported so it propagates to the shared
# $(SOURCE_DEPEND) prerequisite recipe and into the vivado subprocess.
xsim gui : export RUCKUS_SIM_BACKEND := xsim
vcs      : export RUCKUS_SIM_BACKEND := vcs

###############################################################
#### Vivado XSIM Simulation ###################################
###############################################################
.PHONY : xsim
xsim : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado XSIM Simulation")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado/xsim.tcl

###############################################################
#### Vivado VCS Simulation ####################################
###############################################################
.PHONY : vcs
vcs : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generating the VCS Simulation scripts")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado/vcs.tcl

###############################################################
#### Vivado ModelSim/Questa Simulation ########################
###############################################################
.PHONY : msim
msim : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"ModelSim/Questa Simulation")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado/msim.tcl

###############################################################
#### Vivado Batch Mode within the Project Environment  ########
###############################################################
.PHONY : batch
batch : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Project Batch")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado/batch.tcl $(VIVADO_PROJECT).xpr

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY      : sources
sources     : $(SOURCE_DEPEND)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
