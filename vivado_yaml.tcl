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

proc ::findFiles { baseDir pattern } {
  set dirs [ glob -nocomplain -type d [ file join $baseDir * ] ]
  set files {}
  foreach dir $dirs { 
    lappend files {*}[ findFiles $dir $pattern ] 
  }
  lappend files {*}[ glob -nocomplain -type f [ file join $baseDir $pattern ] ] 
  return $files
}

# Check for top level YAML file
if { [file exists ${PROJ_DIR}/yaml/000TopLevel.yaml] != 1 } {
   puts "\n\nERROR: ${PROJ_DIR}/yaml/000TopLevel.yaml does NOT exist\n\n"
   exit -1
} 
   
if { [info exists ::env(COMMON_FILE)] != 1 } {
   puts "\n\nERROR: COMMON_FILE is not defined in $::env(PROJ_DIR)/Makefile\n\n"
   exit -1
}
   
# Common Variable
set ProjYamlDir "${OUT_DIR}/${PROJECT}_project.yaml"

# Check if the directory exists
if [file exists ${ProjYamlDir}] {
   exec rm -rf ${ProjYamlDir}/*
} else {
   exec mkdir ${ProjYamlDir}
}

# Copy all of the submodule yaml files
set listFiles  [ findFiles ${TOP_DIR}/submodules "*.yaml" ]
foreach filename ${listFiles} {  
   exec cp -f ${filename} ${ProjYamlDir}/
}     

# Copy all of the comon directory's yaml files
set listFiles  [ findFiles ${TOP_DIR}/common/$::env(COMMON_FILE) "*.yaml" ]
foreach filename ${listFiles} {   
   exec cp -f ${filename} ${ProjYamlDir}/
}   

# Copy all of the target yaml files
set listFiles  [ findFiles ${PROJ_DIR} "*.yaml" ]
foreach filename ${listFiles} {   
   exec cp -f ${filename} ${ProjYamlDir}/
}

# Copy the Version.vhd and the LICENSE.txt to the project's YAML directory
exec cp -f ${PROJ_DIR}/build.info   ${ProjYamlDir}/. 
exec cp -f ${RUCKUS_DIR}/LICENSE.txt ${ProjYamlDir}/.

# Compress the project's YAML directory to the target's image directory
exec tar -zcvf  ${IMAGES_DIR}/$::env(FILE_NAME).tar.gz -C ${OUT_DIR} ${PROJECT}_project.yaml
puts "${IMAGES_DIR}/$::env(FILE_NAME).tar.gz"
