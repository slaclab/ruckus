##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Load RUCKUS environment and library
source $::env(RUCKUS_FAB_DIR)/proc.tcl
source $::env(RUCKUS_FAB_DIR)/env_var.tcl

# Run the user configuration script
SourceTclFile ${PROJ_DIR}/fabulous.tcl

# Copy User Tiles (if they exist)
CopyUserTiles

# Load fabric
load_fabric

# Build the fabric
run_FABulous_fabric

# Check DUMP_HDL env var
if { ${DUMP_HDL} != 1 } {

   # Copy over the user design files
   if { [CopyUserDesign] == 1 } {

      # Generate the bitstream
      run_FABulous_bitstream {npnr user_design/top.v}

      # Copy the bitstream file to image directory
      CopyBitstream
   }


} else {

   # Copy the bitstream file to image directory
   CopyFabricHdlFiles

}

exit