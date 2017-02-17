##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Vivado PROMGEN Build Script

set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

# Target PROMGEN script
set inputFile     "$::env(IMPL_DIR)/$::env(PROJECT).bit"
set outputFile    "$::env(IMPL_DIR)/$::env(PROJECT).mcs"
set outputFilePri "$::env(IMPL_DIR)/$::env(PROJECT)_primary.mcs"
set outputFileSec "$::env(IMPL_DIR)/$::env(PROJECT)_secondary.mcs"
set imagesFile    "$::env(IMAGES_DIR)/$::env(FILE_NAME).mcs"
set imagesFilePri "$::env(IMAGES_DIR)/$::env(FILE_NAME)_primary.mcs"
set imagesFileSec "$::env(IMAGES_DIR)/$::env(FILE_NAME)_secondary.mcs"
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
   exec cp -f ${outputFilePri} ${imagesFilePri}
   exec cp -f ${outputFileSec} ${imagesFileSec}
   # Create a compressed version of the image files
   exec gzip -c -f -9 ${imagesFilePri} > ${imagesFilePri}.gz   
   exec gzip -c -f -9 ${imagesFileSec} > ${imagesFileSec}.gz   
# Else single file PROM format
} else {
   # Copy the image from build tree to source tree
   exec cp -f ${outputFile} ${imagesFile}
   # Create a compressed version of the image file
   exec gzip -c -f -9 ${imagesFile} > ${imagesFile}.gz
}

