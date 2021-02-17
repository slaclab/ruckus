##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/run/post/gui_write.tcl

# Get variables and Custom Procedures
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

########################################################
## Copy the FW image files
########################################################
if { [isVersal] } {
} else {
   # Copy the .bit file (and create .mcs)
   CreateFpgaBit
} else {
   # Create Versal Output files
   CreateVersalOutputs
}
