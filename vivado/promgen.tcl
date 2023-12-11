##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/promgen.tcl
# \brief This script builds the .MCS PROM file

source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Target PROMGEN script
set topModule [file rootname [file tail [glob -dir ${IMPL_DIR} *.bit]]]
set inputFile     "$::env(IMPL_DIR)/${topModule}.bit"
set outputFile    "$::env(IMPL_DIR)/${topModule}.mcs"
set outputFilePri "$::env(IMPL_DIR)/${topModule}_primary.mcs"
set outputFileSec "$::env(IMPL_DIR)/${topModule}_secondary.mcs"
set imagesFile    "$::env(IMAGES_DIR)/$::env(IMAGENAME).mcs"
set imagesFilePri "$::env(IMAGES_DIR)/$::env(IMAGENAME)_primary.mcs"
set imagesFileSec "$::env(IMAGES_DIR)/$::env(IMAGENAME)_secondary.mcs"
set loadbit       "up 0x0 ${inputFile}"
set loaddata      ""

source ${VIVADO_DIR}/promgen.tcl

# Check for non-user data
if { ${loaddata} != "" } {
   puts ${inputFile}
   puts ${outputFile}
   puts ${loadbit}
   puts ${loaddata}
   write_cfgmem -force \
      -format ${format} \
      -interface ${inteface} \
      -size ${size} \
      -loadbit ${loadbit} \
      -loaddata ${loaddata} \
      -file ${outputFile}
} else {
   puts ${inputFile}
   puts ${outputFile}
   puts ${loadbit}
   write_cfgmem -force \
      -format ${format} \
      -interface ${inteface} \
      -size ${size} \
      -loadbit ${loadbit} \
      -file ${outputFile}
}

# Check for SPIx8
if { ${inteface} == "SPIx8" } {

   # Copy the images from build tree to source tree
   if { $::env(GEN_MCS_IMAGE) != 0 } {
      exec cp -f ${outputFilePri} ${imagesFilePri}
      puts "PROM file copied to ${imagesFilePri}"
      exec cp -f ${outputFileSec} ${imagesFileSec}
      puts "PROM file copied to ${imagesFileSec}"
   }

   # Check if gzip-ing the image files
   if { $::env(GEN_MCS_IMAGE_GZIP) != 0 } {
      # Create a compressed version of the image files
      exec gzip -c -f -9 ${outputFilePri} > ${imagesFilePri}.gz
      puts "PROM file copied to ${imagesFilePri}.gz"
      exec gzip -c -f -9 ${outputFileSec} > ${imagesFileSec}.gz
      puts "PROM file copied to ${imagesFileSec}.gz"
   }

# Else single file PROM format
} else {

   # Copy the image from build tree to source tree
   if { $::env(GEN_MCS_IMAGE) != 0 } {
      exec cp -f ${outputFile} ${imagesFile}
      puts "PROM file copied to ${imagesFile}"
   }

   # Check if gzip-ing the image files
   if { $::env(GEN_MCS_IMAGE_GZIP) != 0 } {
      # Create a compressed version of the image file
      exec gzip -c -f -9 ${outputFile} > ${imagesFile}.gz
      puts "PROM file copied to ${imagesFile}.gz"
   }

}
