##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Get variables and Custom Procedures
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Setup pre and post scripts for synthesis
set_property STEPS.SYNTH_DESIGN.TCL.PRE  ${RUCKUS_DIR}/vivado_pre_synth_run.tcl  [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.TCL.POST ${RUCKUS_DIR}/vivado_post_synth_run.tcl [get_runs synth_1]

# Setup pre and post scripts for implementation
set_property STEPS.OPT_DESIGN.TCL.PRE                  ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.TCL.PRE            ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.TCL.PRE                ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE             ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.PRE                ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.PRE  ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]
set_property STEPS.WRITE_BITSTREAM.TCL.PRE             ${RUCKUS_DIR}/vivado_messages.tcl [get_runs impl_1]

# Refer to http://www.xilinx.com/support/answers/65415.html
if { [expr { ${VIVADO_VERSION} >= 2016.1 }] } {
   set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
}

# Enable physical optimization for register replication
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Enable .bin generation for partial reconfiguration
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

# Target specific properties script
SourceTclFile ${VIVADO_DIR}/properties.tcl
