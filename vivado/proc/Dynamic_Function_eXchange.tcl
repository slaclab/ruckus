##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

###############################################################
#### Partial Reconfiguration Functions ########################
###############################################################

## Import static checkpoint
proc ImportStaticReconfigDcp { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Check for valid file path
   if { [file exists ${RECONFIG_CHECKPOINT}] != 1 } {
      puts "\n\n\n\n\n********************************************************"
      puts "${RECONFIG_CHECKPOINT} doesn't exist"
      puts "********************************************************\n\n\n\n\n"
   }

   # Backup the Partial Reconfiguration RTL Block checkpoint and reports
   exec cp -f ${SYN_DIR}/${PRJ_TOP}.dcp                   ${SYN_DIR}/${PRJ_TOP}_backup.dcp
   exec mv -f ${SYN_DIR}/${PRJ_TOP}_utilization_synth.rpt ${SYN_DIR}/${PRJ_TOP}_utilization_synth_backup.rpt
   exec mv -f ${SYN_DIR}/${PRJ_TOP}_utilization_synth.pb  ${SYN_DIR}/${PRJ_TOP}_utilization_synth_backup.pb

   # Open the static design check point
   open_checkpoint ${RECONFIG_CHECKPOINT}

   # Clear out the targeted reconfigurable module logic
   if { [get_property IS_BLACKBOX [get_cells ${RECONFIG_ENDPOINT}]]  != 1 } {
      update_design -cell ${RECONFIG_ENDPOINT} -black_box
   }

   # Lock down all placement and routing of the static design
   lock_design -level routing

   # Read the targeted reconfiguration RTL block's checkpoint
   read_checkpoint -cell ${RECONFIG_ENDPOINT} ${SYN_DIR}/${PRJ_TOP}.dcp

   # Check for DRC
   report_drc -file ${SYN_DIR}/${PRJ_TOP}_reconfig_drc.txt

   # Overwrite the existing synth_1 checkpoint, which is the
   # checkpoint that impl_1 will refer to
   write_checkpoint -force ${SYN_DIR}/${PRJ_TOP}.dcp

   # Generate new top level reports to update GUI display
   report_utilization -file ${SYN_DIR}/${PRJ_TOP}_utilization_synth.rpt -pb ${SYN_DIR}/${PRJ_TOP}_utilization_synth.pb

   # Get the name of the static build before closing .DCP file
   set staticTop [get_property  TOP [current_design]]

   # Close the opened design before launching the impl_1
   close_design

   # Set the top-level RTL (required for Ultrascale)
   set_property top ${staticTop} [current_fileset]

   # SYNTH is not out-of-date
   set_property NEEDS_REFRESH false [get_runs synth_1]
}

## Export partial configuration bin file
proc ExportStaticReconfigDcp { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Make a copy of the .dcp file with a "_static" suffix
   exec cp -f ${IMPL_DIR}/${PROJECT}_routed.dcp ${IMAGES_DIR}/$::env(IMAGENAME)_static.dcp

   # Get a list of all the clear bin files
   set clearList [glob -nocomplain ${IMPL_DIR}/*_partial_clear.bin]
   if { ${clearList} != "" } {
      foreach clearFile ${clearList} {
         exec cp -f ${clearFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bin
      }
   }

   # Get a list of all the clear bit files
   set clearList [glob -nocomplain ${IMPL_DIR}/*_partial_clear.bit]
   if { ${clearList} != "" } {
      foreach clearFile ${clearList} {
         exec cp -f ${clearFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bit
      }
   }
}

## Export partial configuration bin file
proc ExportPartialReconfigBin { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Define the build output .bit file paths
   set partialBinFile ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial.bin
   set clearBinFile   ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial_clear.bin

   # Overwrite the build output's ${PROJECT}.bit
   exec cp -f ${partialBinFile} ${IMPL_DIR}/${PROJECT}.bin

   # Check for partial_clear.bit (generated for Ultrascale FPGAs)
   if { [file exists ${clearBinFile}] == 1 } {
      exec cp -f ${clearBinFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bin
   }
}

## Export partial configuration bit file
proc ExportPartialReconfigBit { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Define the build output .bit file paths
   set partialBitFile ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial.bit
   set clearBitFile   ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial_clear.bit

   # Overwrite the build output's ${PROJECT}.bit
   exec cp -f ${partialBitFile} ${IMPL_DIR}/${PROJECT}.bit

   # Check for partial_clear.bit (generated for Ultrascale FPGAs)
   if { [file exists ${clearBitFile}] == 1 } {
      exec cp -f ${clearBitFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bit
   }
}