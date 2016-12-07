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

# Top level directories
ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

ifndef TOP_DIR
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)
endif

ifndef MODULES
export MODULES = $(TOP_DIR)/submodules
endif

# Project Build Directory
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
export IMPL_DIR = $(OUT_DIR)/$(VIVADO_PROJECT).runs/impl_1

# Synthesis Variables
export VIVADO_VERSION   = $(shell vivado -version | grep -Po "(\d+\.)+\d+")
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(PROJECT)_project.xpr
ifndef RUCKUS_DIR
export RUCKUS_DIR = $(MODULES)/ruckus
endif
export SOURCE_DEPEND    = $(OUT_DIR)/$(PROJECT)_sources.txt

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Get Project Version
export PRJ_VERSION = $(shell grep FPGA_VERSION_C $(PROJ_DIR)/Version.vhd | sed 's|.*x"\(\S\+\)";.*|\1|')

# SDK Variables
export SDK_PRJ = $(abspath $(OUT_DIR)/$(VIVADO_PROJECT).sdk)
export SDK_ELF = $(abspath $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).elf)

ifndef SDK_LIB
export SDK_LIB  =  $(MODULES)/surf/xilinx/general/sdk/common
endif

define ACTION_HEADER
@echo 
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project = $(PROJECT)"
@echo    "   Out Dir = $(OUT_DIR)"
@echo    "   Version = $(PRJ_VERSION)"
@echo -e "   Changed = $(foreach ARG,$?,$(ARG)\n            )"
@echo    "============================================================================="
@echo 	
endef

.PHONY : all
all: target

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

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : dir
dir:

###############################################################
#### Vivado Project ###########################################
###############################################################
$(VIVADO_DEPEND) :
	$(call ACTION_HEADER,"Vivado Project Creation")
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
	@cd $(OUT_DIR); rm -f firmware
	@cd $(OUT_DIR); ln -s $(TOP_DIR) firmware
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_project.tcl

###############################################################
#### Vivado Sources ###########################################
###############################################################
$(SOURCE_DEPEND) : $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado Source Setup")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_sources.tcl

###############################################################
#### Vivado Batch #############################################
###############################################################
$(IMPL_DIR)/$(PROJECT).bit : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Build")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl
#### Vivado Batch (Partial Reconfiguration: Static) ###########
$(IMPL_DIR)/$(PROJECT)_static.bit : $(RTL_FILES) $(XDC_FILES) $(TCL_FILES) $(CORE_FILES) $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Build (Partial Reconfiguration: Static)")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build_static.tcl
#### Vivado Batch (Partial Reconfiguration: Dynamic) ##########
$(IMPL_DIR)/$(PROJECT)_dynamic.bit : $(RTL_FILES) $(XDC_FILES) $(TCL_FILES) $(CORE_FILES) $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Build (Partial Reconfiguration: Dynamic)")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_build_dynamic.tcl

###############################################################
#### Bitfile Copy #############################################
###############################################################
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit : $(IMPL_DIR)/$(PROJECT).bit
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"
#### Bitfile Copy (Partial Reconfiguration: Static) ###########
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION)_static.bit : $(IMPL_DIR)/$(PROJECT)_static.bit
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION)_static.dcp : $(IMPL_DIR)/$(PROJECT)_static.dcp
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Checkpoint file copied to $@"
	@echo "Don't forget to 'svn commit' when the image and checkpoint is stable!" 
#### Bitfile Copy (Partial Reconfiguration: Dynamic) ##########
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION)_dynamic.bit : $(IMPL_DIR)/$(PROJECT)_dynamic.bit
	@cp $< $@
	@gzip -c -f -9 $@ > $@.gz
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"  

###############################################################
#### Vivado Interactive #######################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Interactive")
	@cd $(OUT_DIR); vivado -mode tcl -source $(RUCKUS_DIR)/vivado_env_var.tcl

###############################################################
#### Vivado Gui ###############################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado GUI")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_gui.tcl

###############################################################
#### Vivado VCS ###############################################
###############################################################
.PHONY : vcs
vcs : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado VCS")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_vcs.tcl

###############################################################
#### Vivado Sythnesis Only ####################################
###############################################################
.PHONY : syn
syn : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis Only")
	@cd $(OUT_DIR); export SYNTH_ONLY=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl

###############################################################
#### Vivado Sythnesis DCP  ####################################
###############################################################
.PHONY : dcp
dcp : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado Synthesis DCP")
	@cd $(OUT_DIR); export SYNTH_DCP=1; vivado -mode batch -source $(RUCKUS_DIR)/vivado_build.tcl

###############################################################
#### Prom #####################################################
###############################################################
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs: $(IMPL_DIR)/$(PROJECT).bit
	$(call ACTION_HEADER,"PROM Generate")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_promgen.tcl
	@echo ""
	@echo "Prom file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

###############################################################
#### BitBin ###################################################
###############################################################
$(IMPL_DIR)/$(PROJECT).bitbin : $(IMPL_DIR)/$(PROJECT).bit
	$(call ACTION_HEADER,"Binary Bit file Generate")
	@cd $(OUT_DIR); promgen -intstyle silent -p bin -data_width 32 -b -w -u 0x0 $(IMPL_DIR)/$(PROJECT).bit
	@mv $(IMPL_DIR)/$(PROJECT).bin $(IMPL_DIR)/$(PROJECT).bitbin

###############################################################
#### BitBin Copy ##############################################
###############################################################
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bitbin : $(IMPL_DIR)/$(PROJECT).bitbin
	@cp $< $@
	@echo ""
	@echo "Binary bit file generated at $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

###############################################################
#### Vivado SDK ###############################################
###############################################################
.PHONY : sdk
sdk : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado SDK GUI")
	@cd $(OUT_DIR); xsdk -workspace $(OUT_DIR)/$(VIVADO_PROJECT).sdk \
      -vmargs -Dorg.eclipse.swt.internal.gtk.cairoGraphics=false

###############################################################
#### Vivado SDK ELF ###########################################
###############################################################
.PHONY : elf
elf : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado SDK .ELF generation")
	@cd $(OUT_DIR); vivado -mode batch -source $(RUCKUS_DIR)/vivado_sdk_bit.tcl
	@echo ""
	@echo "Bit file w/ Elf file copied to $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit"
	@echo "Don't forget to 'svn commit' when the image is stable!"  

###############################################################
#### Vivado YAML ##############################################
###############################################################
.PHONY : yaml
yaml : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Generaring YAML.tar.gz file")
	@cd $(OUT_DIR); tclsh $(VIVADO_BUILD_DIR)/vivado_yaml_v1.tcl

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY      : depend
depend      : $(VIVADO_DEPEND)

.PHONY      : sources
sources     : $(SOURCE_DEPEND)

.PHONY      : bit
bit         : $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit 

.PHONY      : bit_static
bit_static  : $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION)_static.bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION)_static.dcp 

.PHONY      : bit_dynamic
bit_dynamic : $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION)_dynamic.bit

.PHONY      : bitbin
bitbin      : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bitbin

.PHONY      : prom
prom        : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs

.PHONY      : prom_static
prom_static : bit_static $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
