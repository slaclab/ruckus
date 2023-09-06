##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Project Base Path
ifndef TOP_DIR
export TOP_DIR = $(realpath $(PWD)/../.. )
endif

# Project Name
ifndef PROJECT
export PROJECT = $(notdir $(TOP_DIR))
endif

# ROOT Directory Name
ifndef ROOTDIR
export ROOTDIR = $(firstword $(subst /, ,$(TOP_DIR)))
endif

# Release Directory Path
ifndef RELEASE
export RELEASE = $(realpath $(PWD))/release
endif

# Release IP name
ifndef IP_NAME
export IP_NAME = ASIC
endif

# Design libraries
ifndef DESIGN_LIBS
export DESIGN_LIBS = work
endif

# Simulation root library directory
ifndef SIM_LIB_DIR
export SIM_LIB_DIR = vcs_lib
endif

# Simulation root library directory
ifndef SIM_OUT_DIR
export SIM_OUT_DIR = vcs_output
endif

# VCS elaborate options
ifndef VCS_ELAB_OPTS
export VCS_ELAB_OPTS = -full64 -debug_acc+pp+dmptf +warn=none -kdb -lca -debug_pp -t ps -licqueue -l $(SIM_OUT_DIR)/elaborate.log
endif

# Path to VCS analyze script
ifndef ANALYZE
export ANALYZE = $(realpath $(PWD)/analyze.sh )
endif

# Files/Directories to remove during "clean"
ifndef CLEAN
export CLEAN = $(RELEASE) $(SIM_LIB_DIR) $(SIM_OUT_DIR) *.conf *.rc *.log synopsys_sim.setup csrc simv vcs_output simv.daidir DVEfiles verdiLog inter.vpd ucli.key
endif

all: elaborate

.PHONY : test
test:
	@echo TOP_DIR: $(TOP_DIR)
	@echo PROJECT: $(PROJECT)
	@echo ROOTDIR: $(ROOTDIR)
	@echo RELEASE: $(RELEASE)
	@echo IP_NAME: $(IP_NAME)
	@echo DESIGN_LIBS: $(DESIGN_LIBS)
	@echo SIM_LIB_DIR: $(SIM_LIB_DIR)
	@echo SIM_OUT_DIR: $(SIM_OUT_DIR)
	@echo VCS_ELAB_OPTS: $(VCS_ELAB_OPTS)
	@echo ANALYZE: $(ANALYZE)
	@echo CLEAN: $(CLEAN)
	@echo ELAB_TESTBED: $(ELAB_TESTBED)

# Remove all the compile output files/directories
clean:
	rm -rf $(CLEAN)

# Create all the directories
dir: $(DESIGN_LIBS)
	mkdir -p $(SIM_OUT_DIR)

# Create the DESIGN_LIBS directory
$(DESIGN_LIBS): $(SIM_LIB_DIR)
	mkdir -p $(SIM_LIB_DIR)/$@
	echo $@:$(SIM_LIB_DIR)/$@ >> synopsys_sim.setup

# Create the synopsys_sim.setup and SIM_LIB_DIR directory
$(SIM_LIB_DIR):
	mkdir -p $@
	rm -f synopsys_sim.setup
	touch synopsys_sim.setup
	echo "WORK > DEFAULT" >> synopsys_sim.setup
	echo DEFAULT:$(SIM_LIB_DIR)/work >> synopsys_sim.setup

# VCS analyze
analyzes: dir
	$(ANALYZE) 1

# VCS elaborate
elaborate: analyzes
	vcs $(VCS_ELAB_OPTS) $(ELAB_TESTBED) -o simv

# VCS GUI
gui: elaborate
	./simv -gui -l gui.log&

# VCS gen_vcs_ip
gen_vcs_ip: dir
	# Generate the IP release
	gen_vcs_ip -top_name $(IP_NAME) -ipdir $(RELEASE) -noencrypt -parse -e "$(ANALYZE) 0"

	# Reorganize  the released source code
	mv $(RELEASE)/$(TOP_DIR) $(RELEASE)/$(PROJECT)
	rm -rf $(RELEASE)/$(ROOTDIR)

	# Update the metadata file's source code paths
	sed -i 's+$(TOP_DIR)+/$(PROJECT)+g' $(RELEASE)/*file_list.*
	sed -i 's+____ ./$(ROOTDIR)+____ ./$(PROJECT)+g' $(RELEASE)/GENIP_README

# VCS pre-compiled IP
pre_compiled_ip: dir
	$(ANALYZE) 0
	vcs -lca -genip $(IP_NAME) -dir=$(RELEASE)
