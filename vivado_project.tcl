##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Project Batch-Mode Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Message Filtering Script
source -quiet ${RUCKUS_DIR}/vivado_messages.tcl

# Setup project properties
source ${RUCKUS_DIR}/vivado_properties.tcl

# Target specific project setup script
VivadoRefresh ${VIVADO_PROJECT}
SourceTclFile ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project

# Check if image directory doesn't exist
if { [file exists ${IMAGES_DIR}] != 1 } {   
   exec mkdir ${IMAGES_DIR}
}
