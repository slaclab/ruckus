##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_pyrogue.tcl
# \brief This script tarballs all the rogue python source code

# Get variables and Custom Procedures
source $::env(RUCKUS_DIR)/vivado_env_var.tcl

# Variables 
set PyRogueDirName  $::env(IMAGENAME).python
set ProjPythonDir   "${OUT_DIR}/${PyRogueDirName}"

# Remove old directory and files
exec rm -rf ${ProjPythonDir}
exec rm -rf ${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.zip

# Create a new directory
exec mkdir ${ProjPythonDir}
exec mkdir ${ProjPythonDir}/python

# Get the ruckus.tcl directory list
set dirList [read [open ${OUT_DIR}/dirList.txt]] 

# check for non-empty list
if { ${dirList} != "" } {
   # Loop through the list
   foreach dirPntr ${dirList} {
      # Check if python directory exist
      if { [file isdirectory ${dirPntr}/python/] == 1 } {
         # Create a list of files
         set fileList [glob -dir ${dirPntr}/python/ *]
         # check for non-empty list
         if { ${fileList} != "" } {
            # Loop through the list
            foreach filePntr ${fileList} {      
               # Copy all the files
               exec cp -rf ${filePntr} ${ProjPythonDir}/python/.
            }
         }
      }
   }
}

# Always copy TOP_DIR/firmware/python directory if it exists
if { [file isdirectory ${TOP_DIR}/python/] == 1 } {
   # Create a list of files
   set fileList [glob -dir ${TOP_DIR}/python/ *]
   # check for non-empty list
   if { ${fileList} != "" } {
      # Loop through the list
      foreach filePntr ${fileList} {
         # Copy all the files
         exec cp -rf ${filePntr} ${ProjPythonDir}/python/.
      }
   }
}

# Copy the licensing file
exec cp -f ${RUCKUS_DIR}/LICENSE.txt ${ProjPythonDir}/.

# Copy the .ltx file
set filePath "$::env(OUT_DIR)/debugProbes.ltx"; # Vivado 2016 (or earlier)
if { [file exists ${filePath}] == 1 } {
   exec cp -f ${filePath} ${ProjPythonDir}/.
}
set filePath "$::env(IMPL_DIR)/debug_nets.ltx"; # Vivado 2017 (or later)
if { [file exists ${filePath}] == 1 } {
   exec cp -f ${filePath} ${ProjPythonDir}/.
}

# Set the defaults directory
if { [info exists ::env(DEFAULTS_DIR)] != 1 } {
   set defaultsDir "$::env(PROJ_DIR)/config"
} else {
   set defaultsDir "$::env(DEFAULTS_DIR)"
}

# Copy the defaults into the dump directory
if { [file isdirectory ${defaultsDir}] == 1 } {
	exec cp -rf ${defaultsDir} ${ProjPythonDir}/.
} else {
	puts "Note: ${defaultsDir} doesn't exist"
}

# Compress the python directory to the target's image directory
exec zip -r -9 -q ${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.zip ${PyRogueDirName}
puts "${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.zip"

# Create a copy of the tar.gz file with ones padding for PROM loading support (prevent Vivado from unzipping from the load)
if { [file isdirectory $::env(IMPL_DIR)] == 1 } {
   set onesFile "$::env(IMPL_DIR)/ones.bin"
   exec rm -f ${onesFile}
   exec printf "%b" '\xff\xff' > ${onesFile}
   exec cat ${onesFile} ${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.zip    > $::env(IMPL_DIR)/$::env(IMAGENAME).pyrogue.zip
}
