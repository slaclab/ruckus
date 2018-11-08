##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_project.tcl
# \brief This script create the Vivado project

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for unsupported versions that ruckus does NOT support
CheckVivadoVersion

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Message Filtering Script
source -quiet ${RUCKUS_DIR}/vivado_messages.tcl

# Set VHDL as preferred language
set_property target_language VHDL [current_project]

# Disable Xilinx's WebTalk
config_webtalk -user off

# Default to no flattening of the hierarchy
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

# Close and reopen project to force the physical path of ${RUCKUS_DIR} (bug in Vivado 2014.1)
VivadoRefresh ${VIVADO_PROJECT}

# Setup project properties
source ${RUCKUS_DIR}/vivado_properties.tcl

# Set the messaging limit
set_param messaging.defaultLimit 10000

# Vivado simulation properties
set_property simulator_language Mixed [current_project]
set_property nl.process_corner slow   [get_filesets sim_1]
set_property nl.sdf_anno true         [get_filesets sim_1]
set_property SOURCE_SET sources_1     [get_filesets sim_1]

if { [expr { ${VIVADO_VERSION} <= 2014.2 }] } {
   set_property runtime {}             [get_filesets sim_1]
   set_property xelab.debug_level all  [get_filesets sim_1]
   set_property xelab.mt_level auto    [get_filesets sim_1]
   set_property xelab.sdf_delay sdfmin [get_filesets sim_1]
   set_property xelab.rangecheck false [get_filesets sim_1]
   set_property xelab.unifast false    [get_filesets sim_1]
} else {
   set_property xsim.simulate.runtime {}  [get_filesets sim_1]
   set_property xsim.debug_level all      [get_filesets sim_1]
   set_property xsim.mt_level auto        [get_filesets sim_1]
   set_property xsim.sdf_delay sdfmin     [get_filesets sim_1]
   set_property xsim.rangecheck false     [get_filesets sim_1]
   set_property xsim.unifast false        [get_filesets sim_1]
} 

# Enable general project multi-threading
set cpuNum [GetCpuNumber]
if { ${cpuNum} >= 8 } { 
   set_param general.maxThreads 8
} else {
   set_param general.maxThreads ${cpuNum}
}

# Target specific project setup script
VivadoRefresh ${VIVADO_PROJECT}
SourceTclFile ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project
