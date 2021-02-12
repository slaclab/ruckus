##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/post_synth_run.tcl
# \brief This script runs at the end of the synthesis run (inside of synth_1)

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

# Check if Multi-Driven Nets are not allowed
set AllowMultiDriven [expr {[info exists ::env(ALLOW_MULTI_DRIVEN)] && [string is true -strict $::env(ALLOW_MULTI_DRIVEN)]}]
if { ${AllowMultiDriven} != 1 } {
   # Get the number of errors and multi-driven nets during synthesis
   set MDRV [report_drc -quiet -checks {MDRV-1}]
   # Check if any multi-driven nets during synthesis
   if { ${MDRV} != 0 } {
      puts "\n\n\nMulti-driven nets detected during synthesis!!!\n\n"
      exit -1
   }
}

if { [VersionCompare 2020.2] >= 0 } {
   report_qor_assessment  -name qor_assessment_synth  -file ${SYN_DIR}/qor_assessment_synth.rpt
   report_qor_suggestions -name qor_suggestions_synth -file ${SYN_DIR}/qor_suggestions_synth.rpt
}

# GUI Related:
# Disable a refresh due to the changes
# in the Version.vhd file during synthesis
set_property NEEDS_REFRESH false [current_run]

# Write the GIT hash to a file
set fdOut [open ${SYN_DIR}/git.hash  w]
puts ${fdOut} $::env(GIT_HASH_LONG)
close ${fdOut}

# Target specific post_synthesis script
SourceTclFile ${VIVADO_DIR}/post_synth_run.tcl
