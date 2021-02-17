##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vitis/bit.tcl
# \brief This script rebuild the .bit file with the .elf included

# Get variables and Custom Procedures
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Open the project (in case not already opened)
set open_rc [catch {
   open_project -quiet ${VIVADO_PROJECT}
} _RESULT]

# Check if custom vitis exist
if { [file exists ${VIVADO_DIR}/vitis.tcl] == 1 } {
   source ${VIVADO_DIR}/vitis.tcl
} else {

   # Generate the .XSA file
   write_hw_platform -fixed -force  -include_bit -file ${OUT_DIR}/${PROJECT}.xsa

   # Create the Vitis project
   set src_rc [catch {exec xsct -interactive ${RUCKUS_DIR}/MicroblazeBasicCore/vitis/prj.tcl >@stdout } _RESULT]

   # Generate .ELF
   set src_rc [catch {exec xsct -interactive ${RUCKUS_DIR}/MicroblazeBasicCore/vitis/elf.tcl >@stdout } _RESULT]

   # Add .ELF to the .bit file properties
   set add_rc [catch {
      add_files -norecurse ${VITIS_ELF}
   } _RESULT]
   set_property SCOPED_TO_REF MicroblazeBasicCore [get_files -all -of_objects [get_fileset sources_1] ${VITIS_ELF}]
   set_property SCOPED_TO_CELLS { microblaze_0 }  [get_files -all -of_objects [get_fileset sources_1] ${VITIS_ELF}]

   # Rebuild the .bit file with the .ELF file include
   reset_run impl_1 -prev_step
   launch_runs -to_step write_bitstream impl_1 >@stdout
   set src_rc [catch {
      wait_on_run impl_1
   } _RESULT]

   if { [isVersal] } {
      # Create Versal Output files
      CreateVersalOutputs
   } else {
      # Copy the .bit file (and create .mcs)
      CreateFpgaBit
   }

}
