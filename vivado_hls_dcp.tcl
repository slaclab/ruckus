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
source  -quiet ${RUCKUS_DIR}/vivado_hls_env_var.tcl
source  -quiet ${RUCKUS_DIR}/vivado_hls_proc.tcl 

## Get the file name and path of the new .dcp file
set filename [exec ls [glob "${PROJ_DIR}/ip/*.dcp"]]

## Open the check point
open_checkpoint ${filename}

## Delete all timing constraint for importing into a target vivado project
reset_timing

## Overwrite the checkpoint   
write_checkpoint -force ${filename}

## Print Build complete reminder
PrintBuildComplete ${filename}

## IP is ready for use in target firmware project
exit 0
