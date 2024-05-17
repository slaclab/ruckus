##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vitis/hls/build.tcl
# \brief This script builds the Vitis HLS project in batch mode

# Get variables and Custom Procedures
set RUCKUS_DIR $::env(RUCKUS_DIR)
source ${RUCKUS_DIR}/vitis/hls/env_var.tcl
source ${RUCKUS_DIR}/vitis/hls/proc.tcl

##############################################################################
#                  HLS Project Setup
##############################################################################

# Create a Project
open_project ${PROJECT}_project

# Create a solution
open_solution "solution1"

# Get the directives
source ${PROJ_DIR}/directives.tcl

# Generate the description string for the ip catalog export
if { $::env(GIT_HASH_SHORT) == 0 } {
   set description "$::env(BUILD_STRING), Githash=dirty"
} else {
   set description "$::env(BUILD_STRING), Githash=$::env(GIT_HASH_SHORT)"
}

##############################################################################
#                  Run C/C++ simulation testbed
##############################################################################
if { $::env(SKIP_CSIM) == 0 } {

   set retVal [catch { \
      csim_design -clean -O \
      -ldflags ${LDFLAGS} \
      -mflags ${MFLAGS} \
      -argv ${ARGV} \
   }]

   CheckProcRetVal ${retVal} "csim_design" "vitis/hls/build"

}
##############################################################################
#                  Synthesis C/C++ code into RTL
##############################################################################
set retVal [catch { csynth_design }]
CheckProcRetVal ${retVal} "csynth_design" "vitis/hls/build"

##############################################################################
#      Run co-simulation (compares the C/C++ code to the RTL)
##############################################################################
if { $::env(SKIP_COSIM) == 0 } {

   set retVal [catch { \
      cosim_design -O \
      -trace_level $::env(HLS_SIM_TRACE_LEVEL) \
      -rtl ${HDL_TYPE} \
      -ldflags ${LDFLAGS} \
      -mflags ${MFLAGS} \
      -argv ${ARGV} \
      -tool $::env(HLS_SIM_TOOL) \
      -compiled_library_dir $::env(COMPILED_LIB_DIR) \
   }]

   CheckProcRetVal ${retVal} "cosim_design" "vitis/hls/build"
}

##############################################################################
#                             Export the Design
##############################################################################
set retVal [catch { \
   export_design \
   -description ${description} \
   -display_name ${PROJECT} \
   -format ip_catalog \
   -ipname ${PROJECT} \
   -library hls \
   -taxonomy "/VITIS_HLS_IP" \
   -vendor $::env(EXPORT_VENDOR) \
   -version $::env(EXPORT_VERSION) \
}]

CheckProcRetVal ${retVal} "export_design(zip)" "vitis/hls/build"

# Check if we need to modify the component.xml
if { $::env(ALL_XIL_FAMILY) == 1 } {
   # Modify the component.xml for all fammily support
   ComponentXmlAllFamilySupport
} else {
   # No modification to .ZIP.  Only copy the .ZIP to the output image directory
   set zipFile [glob -directory ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip/ *.zip *.ZIP]
   exec cp -f ${zipFile} ${PROJ_DIR}/ip/${PROJECT}.zip
}
puts "${PROJ_DIR}/ip/${PROJECT}.zip"

##############################################################################
#                            Exit Procedure
##############################################################################

# Close current solution
close_solution

# Close the project
close_project
exit 0
