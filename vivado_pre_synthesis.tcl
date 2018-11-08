##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_pre_synthesis.tcl
# \brief This script runs before the synthesis run (outside of synth_1)

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for optional pre-synthesis elaboration to check for sensitivity list errors
# Note: This step is not added by default to minimize build time (assuming no code errors)
if { [info exists ::env(PRE_SYNTH_ELABORATE)] != 1 || $::env(PRE_SYNTH_ELABORATE) == 0 } {
   set nop 0
} else {
   set elab_rc [catch {synth_design -rtl -name rtl_1 -mode out_of_context -rtl_skip_ip -rtl_skip_constraints -no_timing_driven -assert} _ELAB_RESULT]
   if { ${elab_rc} } {
      PrintOpenGui ${_ELAB_RESULT}
      exit -1
   }   
}

# Target specific pre_synthesis script
SourceTclFile ${VIVADO_DIR}/pre_synthesis.tcl
