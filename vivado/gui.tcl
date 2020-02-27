##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/gui.tcl
# \brief This script launches the Vivado interface GUI mode with all the
# ruckus procedures and environmental variables included

# Get variables and Custom Procedures and common properties
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/properties.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

# Update the bitstream post script
set_property STEPS.WRITE_BITSTREAM.TCL.POST ${RUCKUS_DIR}/vivado/post_route_run.tcl [get_runs impl_1]

# Call the user script
SourceTclFile ${VIVADO_DIR}/gui.tcl

# Bug fix work around for Vivado due to post script changes
if { [CheckSynth] == true } {
   set_property NEEDS_REFRESH 0 [get_runs impl_1]
}
