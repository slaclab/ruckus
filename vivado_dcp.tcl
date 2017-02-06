##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## Get variables and Custom Procedures
set RUCKUS_DIR $::env(RUCKUS_DIR)
source  -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source  -quiet ${RUCKUS_DIR}/vivado_proc.tcl 

## Get the top level name
set topName [get_property top [current_fileset]]

## Get the ouput file path
set filepath "${IMAGES_DIR}/${topName}_${PRJ_VERSION}"

## Open the synthesis design
open_run synth_1 -name synth_1

## Check if we need to remove the timing cosntraints
set RemoveTimingConstraints [expr {[info exists ::env(DCP_REMOVE_TIMING_CONSTRAINT)] && [string is true -strict $::env(DCP_REMOVE_TIMING_CONSTRAINT)]}]  
puts "RemoveTimingConstraints = ${RemoveTimingConstraints}"
if { ${RemoveTimingConstraints} == 1 } {
   ## Delete all timing constraint for importing into a target vivado project
   reset_timing
}

## Create synth_stub
write_vhdl -force -mode synth_stub ${filepath}.vhd

## Overwrite the checkpoint   
write_checkpoint -force ${filepath}.dcp

## Close the checkpoint
close_design

## Parse the synth_stub
exec python ${RUCKUS_DIR}/write_vhd_synth_stub_parser.py ${filepath}.vhd

# Target specific dcp script
SourceTclFile ${VIVADO_DIR}/dcp.tcl

## Print Build complete reminder
DcpCompleteMessage ${filepath}.dcp

## IP is ready for use in target firmware project
exit 0
