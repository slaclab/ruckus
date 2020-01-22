##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vitis/prj.tcl
# \brief This script creates the general Vivado Vitis project

# Get build system variables 
source $::env(RUCKUS_DIR)/vivado/env_var.tcl

# Remove the Vitis project directory
exec rm -rf ${VITIS_PRJ}

# Make the Vitis project directory
exec mkdir ${VITIS_PRJ}

# Set the workspace
setws ${VITIS_PRJ}

# Create the application
app create \
   -name app_0 \
   -hw ${OUT_DIR}/${PROJECT}.xsa  \
   -proc microblaze_0 \
   -template {Empty Application} \
   -os standalone \
   -lang {c++}

# Configure the "debug" application
app config -name app_0 build-config debug
app config -name app_0 -set compiler-optimization {Optimize for size (-Os)}

# Add user libraries
foreach vitisLib ${VITIS_LIB} {
   app config -name app_0 -add include-path ${vitisLib}
}

# Configure the "release" application
app config -name app_0 build-config release
app config -name app_0 -set compiler-optimization {Optimize for size (-Os)}

# Add user libraries
foreach vitisLib ${VITIS_LIB} {
   set dirName  [file tail ${vitisLib}]
   set softLink ${VITIS_PRJ}/app_0/${dirName}
   exec ls -lath 
   exec ln -s ${vitisLib} ${softLink}
   app config -name app_0 -add include-path ${vitisLib}
}

# Create a soft-link and add new linker to source tree
if { [file exists ${VITIS_PRJ}/app_0/src/lscript.ld] == 1 } {
   exec cp -f ${VITIS_PRJ}/app_0/src/lscript.ld ${VITIS_PRJ}/app_0/lscript.ld
}
exec rm -rf ${VITIS_PRJ}/app_0/src
exec ln -s $::env(VITIS_SRC_PATH) ${VITIS_PRJ}/app_0/src
if { [file exists ${VITIS_PRJ}/app_0/lscript.ld] == 1 } {
   exec mv -f ${VITIS_PRJ}/app_0/lscript.ld ${VITIS_PRJ}/app_0/src/lscript.ld
}

# Get a list of applications
set appList [app list]

# Generate the platform
platform generate

# Generate the bsp
bsp regenerate

# Exit the `xsct -interactive`
exit
