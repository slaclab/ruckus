##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/batch.tcl
# \brief This script launches the Vivado project then runs User batch.tcl script
# with all the ruckus procedures and environmental variables included

# Get variables and Custom Procedures and common properties
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/properties.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
if { [isVersal] } {
   set_property STEPS.WRITE_DEVICE_IMAGE.TCL.POST ${RUCKUS_DIR}/vivado/run/post/route.tcl [get_runs impl_1]
} else {
   set_property STEPS.WRITE_BITSTREAM.TCL.POST ${RUCKUS_DIR}/vivado/run/post/route.tcl [get_runs impl_1]
}

# Run user's batch script
source ${VIVADO_DIR}/batch.tcl
