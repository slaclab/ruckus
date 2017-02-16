##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Post-Synthesis Run Script

########################################################
## Get variables and Custom Procedures
########################################################
set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl
source -quiet ${RUCKUS_DIR}/vivado_messages.tcl

# Check if Multi-Driven Nets are not allowed
set AllowMultiDriven [expr {[info exists ::env(ALLOW_MULTI_DRIVEN)] && [string is true -strict $::env(ALLOW_MULTI_DRIVEN)]}]  
if { ${AllowMultiDriven} != 1 } {
   # Get the number of errors and multi-driven nets during synthesis
   set MDRV [report_drc -quiet -checks {MDRV-1}]
   # Check if any multi-driven nets during synthesis
   if { ${MDRV} != 0 } {
      puts "\n\n\nMulti-driven nets detected during synthesis!!!n\n\n"    
      exit -1
   }
}

# GUI Related:
# Disable a refresh due to the changes 
# in the Version.vhd file during synthesis 
set_property NEEDS_REFRESH false [current_run]

# Target specific post_synthesis script
SourceTclFile ${VIVADO_DIR}/post_synth_run.tcl
