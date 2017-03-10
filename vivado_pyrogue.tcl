##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set RUCKUS_DIR $::env(RUCKUS_DIR)
source ${RUCKUS_DIR}/vivado_env_var.tcl

proc FindPythonDir { baseDir } {
   set src_rc [catch {
      set dirPaths [glob -types d  ${baseDir}/python/*]
   } _RESULT] 
   if {$src_rc} { 
      return "";
   } else {
      return ${dirPaths};
   }
}

# Variables 
set ProjYamlDir   "${OUT_DIR}/python"
set submoduleDir  [FindPythonDir ${TOP_DIR}/submodules/*]
set commonDir     [FindPythonDir ${TOP_DIR}/common/*]
set targetDir     [FindPythonDir ${PROJ_DIR}]

# Remove old directory and files
exec rm -rf ${ProjYamlDir}
exec rm -rf ${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.tar.gz

# Create a new directory
exec mkdir ${ProjYamlDir}

# Copy python modules from submodules
if { ${submoduleDir} != "" } {
   foreach dirName ${submoduleDir} {  
      exec cp -rf ${dirName} ${ProjYamlDir}/
   }     
}

# Copy python modules from common
if { ${commonDir} != "" } {
   foreach dirName ${commonDir} {  
      exec cp -rf ${dirName} ${ProjYamlDir}/
   }     
}

# Copy python modules from target
if { ${targetDir} != "" } {
   foreach dirName ${targetDir} {  
      exec cp -rf ${dirName} ${ProjYamlDir}/
   }     
}

# Copy the licensing file
exec cp -f ${RUCKUS_DIR}/LICENSE.txt ${ProjYamlDir}/.

# Copy the build.info
if { $::env(GIT_HASH_LONG) != "" } {
   if { [file exists ${PROJ_DIR}/build.info] == 1 } {
      exec cp -f ${PROJ_DIR}/build.info ${ProjYamlDir}/.
   } 
} 

# Compress the python directory to the target's image directory
exec tar -zcvf  ${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.tar.gz -C ${OUT_DIR} python
puts "${IMAGES_DIR}/$::env(IMAGENAME).pyrogue.tar.gz"
