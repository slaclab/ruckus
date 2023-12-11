##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## Create .MCS PROM
proc CreatePromMcs { } {
   if { [file exists $::env(PROJ_DIR)/vivado/promgen.tcl] == 1 } {
      source $::env(RUCKUS_DIR)/vivado/promgen.tcl
   }
}

## Create .BIT file
proc CreateFpgaBit { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
   set imagePath "${IMAGES_DIR}/$::env(IMAGENAME)"
   set topModule [file rootname [file tail [glob -dir ${IMPL_DIR} *.bit]]]

   # Copy the .BIT file to image directory
   if { $::env(GEN_BIT_IMAGE) != 0 } {
      exec cp -f ${IMPL_DIR}/${topModule}.bit ${imagePath}.bit
      puts "Bit file copied to ${imagePath}.bit"
   }
   if { $::env(GEN_BIT_IMAGE_GZIP) != 0 } {
      exec gzip -c -f -9 ${IMPL_DIR}/${topModule}.bit > ${imagePath}.bit.gz
      puts "Bit file copied to ${imagePath}.bit.gz"
   }

   # Copy the .BIN file to image directory
   if { $::env(GEN_BIN_IMAGE) != 0 } {
      exec cp -f ${IMPL_DIR}/${topModule}.bin ${imagePath}.bin
      puts "Bin file copied to ${imagePath}.bin"
   }
   if { $::env(GEN_BIN_IMAGE_GZIP) != 0 } {
      exec gzip -c -f -9 ${IMPL_DIR}/${topModule}.bin > ${imagePath}.bin.gz
      puts "Bin file copied to ${imagePath}.bin.gz"
   }

   # Copy the .ltx file (if it exists)
   CopyLtxFile

   if { $::env(GEN_XSA_IMAGE) != 0 } {
      # Check for Vivado 2019.2 (or newer)
      if { [VersionCompare 2019.2] >= 0 } {
         # Try to generate the .XSA file
         set src_rc [catch { write_hw_platform -fixed -force -include_bit -file ${imagePath}.xsa } _RESULT]

      # Else Vivado 2019.1 (or older)
      } else {
         # Try to generate the .HDF file
         write_hwdef -force -file ${imagePath}.hdf
      }
   }

   # Create the MCS file (if target/vivado/promgen.tcl exists)
   CreatePromMcs
}

## Create Versal Output files
proc CreateVersalOutputs { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
   set imagePath "${IMAGES_DIR}/$::env(IMAGENAME)"
   set topModule [file rootname [file tail [glob -dir ${IMPL_DIR} *.pdi]]]

   # Copy the .pdi file to image directory
   if { $::env(GEN_PDI_IMAGE) != 0 } {
      exec cp -f ${IMPL_DIR}/${topModule}.pdi ${imagePath}.pdi
      puts "PDI file copied to ${imagePath}.pdi"
   }
   # Check if gzip-ing the image files
   if { $::env(GEN_PDI_IMAGE_GZIP) != 0 } {
      exec gzip -c -f -9 ${IMPL_DIR}/${topModule}.pdi > ${imagePath}.pdi.gz
      puts "PDI file copied to ${imagePath}.pdi.gz"
   }

   # Copy the .ltx file (if it exists)
   CopyLtxFile
}

## Create tar.gz of all cpsw files in firmware
proc CreateCpswTarGz { } {
   if { [file exists $::env(PROJ_DIR)/yaml/000TopLevel.yaml] == 1 } {
      source $::env(RUCKUS_DIR)/vivado/cpsw.tcl
   } else {
      puts "$::env(PROJ_DIR)/yaml/000TopLevel.yaml does not exist"
   }
}

## Create tar.gz of all pyrogue files in firmware
proc CreatePyRogueTarGz { } {
   source $::env(RUCKUS_DIR)/vivado/pyrogue.tcl
}

## Copy .LTX file to output image directory
proc CopyLtxFile { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
   set imagePath "${IMAGES_DIR}/$::env(IMAGENAME)"
   # Copy the .ltx file (if it exists)
   if { [file exists ${OUT_DIR}/debugProbes.ltx] == 1 } {
      exec cp -f ${OUT_DIR}/debugProbes.ltx ${imagePath}.ltx
      puts "Debug Probes file copied to ${imagePath}.ltx"
   } elseif { [file exists ${IMPL_DIR}/debug_nets.ltx] == 1 } {
      exec cp -f ${IMPL_DIR}/debug_nets.ltx ${imagePath}.ltx
      puts "Debug Probes file copied to ${imagePath}.ltx"
   } else {
      puts "No Debug Probes found"
   }
}
