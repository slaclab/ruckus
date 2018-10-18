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
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl

set errorDet false

# Work around from artificially generating an "placement" error when using the 
# read_xdc during the end of the synthesis run (within the context of the synthesis run)
# Example: "[Vivado 12-1411] Cannot set LOC property of ports, Site location is not valid"
set_msg_config -suppress -id {Vivado 12-1411}

# Check for "unsafe" timing in the clock interaction report
set src_xdc [catch {read_xdc [get_files {*.xdc} -of_objects [get_filesets {constrs_1}]]} _RESULT]
set crossClkRpt [report_clock_interaction -no_header -return_string]
if { [regexp {(unsafe)} ${crossClkRpt}] != 0 } { 
   puts "\n\n\nWarning: \"Unsafe\" timing in the clock interaction report detected during synthesis!!!\n${crossClkRpt}\n"    
   set errorDet true
}

# Check for "Unconstrained Clocks" in the clock network report
set clkRpt [report_clock_networks -return_string]
if { [regexp {Unconstrained Clocks} ${clkRpt}] != 0 } { 
   puts "\n\n\nWarning: \"Unconstrained Clocks\" in the clock network report detected during synthesis!!!\n${clkRpt}\n"    
   set errorDet true
}

# Check if Multi-Driven Nets are not allowed
set AllowMultiDriven [expr {[info exists ::env(ALLOW_MULTI_DRIVEN)] && [string is true -strict $::env(ALLOW_MULTI_DRIVEN)]}]  
if { ${AllowMultiDriven} != 1 } {
   # Get the number of errors and multi-driven nets during synthesis
   set MDRV [report_drc -quiet -checks {MDRV-1}]
   # Check if any multi-driven nets during synthesis
   if { ${MDRV} != 0 } {
      puts "\n\n\nMulti-driven nets detected during synthesis!!!\n\n"    
      set errorDet true
   }
}

# Check if any post-synthesis errors were detected
if { ${errorDet} != true } {
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
} else {
   # Force the run to be "out of date" by touching top-level file
   exec touch [get_files *[get_property top [get_filesets {sources_1}]].* -of_objects [get_filesets {sources_1}]]
}
