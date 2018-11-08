##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_pre_opt_run.tcl
# \brief This script runs at the beginning of the place and route's optimization run (inside of impl_1)

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl

set errorDet false

# Check for "unsafe" timing in the clock interaction report
set crossClkRpt [report_clock_interaction -no_header -return_string]
if { [regexp {(unsafe)} ${crossClkRpt}] != 0 } { 
   puts "\n\n\nError: \"Unsafe\" timing in the clock interaction report detected during synthesis!!!\n${crossClkRpt}\n"    
   set errorDet true
}

# Check for "Unconstrained Clocks" in the clock network report
set clkRpt [report_clock_networks -return_string]
if { [regexp {Unconstrained Clocks} ${clkRpt}] != 0 } { 
   puts "\n\n\nError: \"Unconstrained Clocks\" in the clock network report detected during synthesis!!!\n${clkRpt}\n"    
   set errorDet true
}

# Check if any post-synthesis errors were detected
if { ${errorDet} != true } {
   # Target specific post_synthesis script
   SourceTclFile ${VIVADO_DIR}/pre_opt_run.tcl
} else {
   exit -1
}
