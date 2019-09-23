##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_gui.tcl
# \brief This script launches the Vivado HLS interface GUI mode with all the 
# ruckus procedures and environmental variables included 

# Get variables and Custom Procedures and common properties
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_properties.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
set_property STEPS.WRITE_BITSTREAM.TCL.POST ${RUCKUS_DIR}/vivado_post_route_run.tcl [get_runs impl_1]
SourceTclFile ${VIVADO_DIR}/gui.tcl
