##############################################################################
## This file is an addition to the 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_sim.tcl
# \brief This script simulates the Vivado project in batch mode

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

########################################################
## Open the project
########################################################

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Setup project properties
source -quiet ${RUCKUS_DIR}/vivado_properties.tcl
set_property STEPS.WRITE_BITSTREAM.TCL.POST "" [get_runs impl_1]

# Setup project messaging
source -quiet ${RUCKUS_DIR}/vivado_messages.tcl

########################################################
## Update the complie order
########################################################
update_compile_order -quiet -fileset sources_1

########################################################
## Check project configuration for errors
########################################################
if { [CheckPrjConfig sources_1] != true ||
     [CheckPrjConfig sim_1]     != true } {
   exit -1
}

########################################################
## Check if we re-synthesis any of the IP cores
########################################################
BuildIpCores

########################################################
## Simulate
########################################################
set sim_rc [catch { 
   ## Set sim properties
   set_property top ${VIVADO_PROJECT_SIM} [get_filesets sim_1]
   set_property top_lib xil_defaultlib [get_filesets sim_1]
   ## Launch the sim
   launch_simulation
   ## Run simulation for time specified
   set VIVADO_PROJECT_SIM_TIME "run ${VIVADO_PROJECT_SIM_TIME}"; # set cmd
   eval ${VIVADO_PROJECT_SIM_TIME}; # run cmd
   set src_rc [catch { 
      wait_on_run sim_1
   } _RESULT]     
} _SIM_RESULT]    

########################################################
# Check for error return code during the process
########################################################
if { ${sim_rc} } {
   PrintOpenGui ${_SIM_RESULT}
   exit -1
}

########################################################
## Check that the process is completed
########################################################
# todo
