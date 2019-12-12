##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file sdk/bit.tcl
# \brief This script rebuild the .bit file with the .elf included

# Get variables and Custom Procedures
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Open the project (in case not already opened)
set open_rc [catch { 
   open_project -quiet ${VIVADO_PROJECT}
} _RESULT]   

# Check if custom SDK exist
if { [file exists ${VIVADO_DIR}/sdk.tcl] == 1 } {   
   source ${VIVADO_DIR}/sdk.tcl
} else {

   # Generate .ELF
   exec xsdk -batch -source ${RUCKUS_DIR}/MicroblazeBasicCore/sdk/elf.tcl >@stdout

   # Add .ELF to the .bit file properties
   set add_rc [catch {
      add_files -norecurse ${SDK_ELF}  
   } _RESULT]  
   set_property SCOPED_TO_REF MicroblazeBasicCore [get_files -all -of_objects [get_fileset sources_1] ${SDK_ELF}]
   set_property SCOPED_TO_CELLS { microblaze_0 }  [get_files -all -of_objects [get_fileset sources_1] ${SDK_ELF}]

   # Rebuild the .bit file with the .ELF file include
   reset_run impl_1 -prev_step
   launch_runs -to_step write_bitstream impl_1 >@stdout
   set src_rc [catch { 
      wait_on_run impl_1 
   } _RESULT]  

   # Copy over .bit w/ .ELF file to image directory
   exec cp -f ${IMPL_DIR}/${PROJECT}.bit ${IMAGES_DIR}/$::env(IMAGENAME).bit
   
   # Check if gzip-ing the image files
   if { $::env(GZIP_BUILD_IMAGE) != 0 } {    
      exec gzip -c -f -9 ${IMPL_DIR}/${PROJECT}.bit > ${IMAGES_DIR}/$::env(IMAGENAME).bit.gz
   }   

}
