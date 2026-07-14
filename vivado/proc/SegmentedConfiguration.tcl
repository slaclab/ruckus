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
#### Versal Segmented Configuration Functions #################
###############################################################

# Versal-only build-flow hook that emits two PDIs (<IMAGENAME>_static.pdi for
# BOOT.BIN, <IMAGENAME>_dynamic.pdi for runtime PL reload) instead of the
# standard single PDI.
#
# Opt in by exporting USE_SEGMENTED_CONFIG = 1 in the target Makefile before
# including system_vivado.mk.
#
# See docs/how-to/segmented_configuration.rst for the full opt-in workflow.

## Enable Segmented Configuration on the current project
proc EnableSegmentedConfig { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Defensive: this proc must only fire on Versal targets.
   if { ![isVersal] } {
      puts "WARNING: USE_SEGMENTED_CONFIG=1 ignored: target FPGA is not Versal"
      return
   }

   # Hard error if Vivado < 2025.1 - Segmented Configuration is unsupported.
   if { [VersionCompare 2025.1] < 0 } {
      set vivadoVer [version -short]
      puts "\n\n********************************************************"
      puts "ERROR: Versal Segmented Configuration requires Vivado 2025.1 or later"
      puts "Currently sourced Vivado version: ${vivadoVer}"
      puts "Remedy: source a 2025.1+ settings64.sh"
      puts "  SLAC AFS path: /sdf/group/faders/tools/xilinx/2025.2/Vivado/2025.2/settings64.sh"
      puts "********************************************************\n\n"
      exit -1
   }

   # Enable Segmented Configuration on the current project.
   # Vivado will emit <design>_boot.pdi and <design>_pld.pdi during write_device_image.
   set_property SEGMENTED_CONFIGURATION 1 [current_project]
   puts "Segmented Configuration enabled on [current_project]"
}

## Export the Segmented Configuration PDI files (static + dynamic)
proc ExportSegmentedPdi { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   set imagePath "${IMAGES_DIR}/$::env(IMAGENAME)"

   # Discover the boot PDI (Vivado emits <design>_boot.pdi)
   set bootList [glob -nocomplain ${IMPL_DIR}/*_boot.pdi]
   if { [llength ${bootList}] != 1 } {
      puts "\n\n********************************************************"
      puts "ExportSegmentedPdi: Expected exactly one *_boot.pdi in ${IMPL_DIR}"
      puts "Found: ${bootList}"
      puts "Did SEGMENTED_CONFIGURATION get set correctly on the project?"
      puts "********************************************************\n\n"
      exit -1
   }
   set bootPdi [lindex ${bootList} 0]

   # Discover the PL PDI (Vivado emits <design>_pld.pdi)
   set pldList [glob -nocomplain ${IMPL_DIR}/*_pld.pdi]
   if { [llength ${pldList}] != 1 } {
      puts "\n\n********************************************************"
      puts "ExportSegmentedPdi: Expected exactly one *_pld.pdi in ${IMPL_DIR}"
      puts "Found: ${pldList}"
      puts "Did SEGMENTED_CONFIGURATION get set correctly on the project?"
      puts "********************************************************\n\n"
      exit -1
   }
   set pldPdi [lindex ${pldList} 0]

   # Copy with SLAC suffix naming (per D-04)
   if { $::env(GEN_PDI_IMAGE) != 0 } {
      exec cp -f ${bootPdi} ${imagePath}_static.pdi
      exec cp -f ${pldPdi}  ${imagePath}_dynamic.pdi
      puts "Static  PDI file copied to ${imagePath}_static.pdi"
      puts "Dynamic PDI file copied to ${imagePath}_dynamic.pdi"
   }

   # Check if gzip-ing the image files
   if { $::env(GEN_PDI_IMAGE_GZIP) != 0 } {
      exec gzip -c -f -9 ${bootPdi} > ${imagePath}_static.pdi.gz
      exec gzip -c -f -9 ${pldPdi}  > ${imagePath}_dynamic.pdi.gz
      puts "Static  PDI file gzip-copied to ${imagePath}_static.pdi.gz"
      puts "Dynamic PDI file gzip-copied to ${imagePath}_dynamic.pdi.gz"
   }

   # Maintain side-effect parity with CreateVersalOutputs:
   # the segmented path REPLACES the single-PDI path (D-06), so .ltx and .xsa
   # must still be emitted here.
   CopyLtxFile
   CreateXsaFile
}
