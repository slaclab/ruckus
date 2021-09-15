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

# Get the top level name
set TOP [get_top]

# Get the directives
source ${PROJ_DIR}/directives.tcl

##############################################################################
#                  Run C/C++ simulation testbed
##############################################################################
if { ${SKIP_CSIM} == 0 } {
   
   set retVal [catch { \
      csim_design -clean -O \
      -ldflags ${LDFLAGS} \
      -mflags ${MFLAGS} \
      -argv ${ARGV}\
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
if { ${SKIP_COSIM} == 0 } {

   set retVal [catch { \
      cosim_design -O \
      -trace_level $::env(HLS_SIM_TRACE_LEVEL) \
      -rtl verilog \
      -ldflags ${LDFLAGS} \
      -mflags ${MFLAGS} \
      -argv ${ARGV} \
      -tool $::env(HLS_SIM_TOOL) \
      -compiled_library_dir $::env(COMPILED_LIB_DIR)\
   }]
   
   CheckProcRetVal ${retVal} "cosim_design" "vitis/hls/build"
}

##############################################################################
#                             Export the Design
##############################################################################
if { ${SKIP_EXPORT} == 0 } {

   set retVal [catch { \
      export_design \
      -flow syn \
      -format syn_dcp \
      -output ${PROJ_DIR}/ip/${PROJECT}.dcp \
   }]
   
   CheckProcRetVal ${retVal} "export_design" "vitis/hls/build"

}

##############################################################################
#                            Exit Procedure
##############################################################################

# Close current solution
close_solution

# Close the project
close_project
exit 0
