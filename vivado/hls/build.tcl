##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/hls/build.tcl
# \brief This script builds the Vivado HLS project in batch mode

# Get variables and Custom Procedures
set RUCKUS_DIR $::env(RUCKUS_DIR)
source ${RUCKUS_DIR}/vivado/hls/env_var.tcl
source ${RUCKUS_DIR}/vivado/hls/proc.tcl

# Create a Project
open_project ${PROJECT}_project

# Create a solution
open_solution "solution1"

# Get the top level name
set TOP [get_top]

# Get the directives
source ${PROJ_DIR}/directives.tcl

# Run C/C++ simulation testbed
set retVal [catch { csim_design -clean -O -ldflags ${LDFLAGS} -mflags ${MFLAGS} -argv ${ARGV} }]
CheckProcRetVal ${retVal} "csim_design" "vivado/hls/build"

# Synthesis C/C++ code into RTL
set retVal [catch { csynth_design }]
CheckProcRetVal ${retVal} "csynth_design" "vivado/hls/build"

# Run co-simulation (compares the C/C++ code to the RTL)
if { [info exists ::env(FAST_DCP_GEN)] == 0 } {
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
   CheckProcRetVal ${retVal} "cosim_design" "vivado/hls/build"
}

# Make the output directories
exec rm -rf ${PROJ_DIR}/ip
exec mkdir ${PROJ_DIR}/ip
exec rm -rf ${PROJ_DIR}/reports
exec mkdir ${PROJ_DIR}/reports

# Copy the HLS csynth reports
exec cp -rf ${OUT_DIR}/${PROJECT}_project/solution1/syn/report ${PROJ_DIR}/reports/syn

# Export the Design
if { [info exists ::env(SKIP_EXPORT)] == 0 } {

   set retVal [catch { export_design -format syn_dcp }]
   CheckProcRetVal ${retVal} "export_design" "vivado/hls/build"

   # Copy over the .DCP file
   exec cp -rf  ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip ${PROJ_DIR}/.

   # Copy the driver to module source tree
   set DRIVER ${OUT_DIR}/${PROJECT}_project/solution1/impl/misc/drivers
   if { [file exist  ${DRIVER}] } {
      set DRIVER ${DRIVER}/[exec ls ${DRIVER}]/src
      set DRIVER [glob ${DRIVER}/*_hw.h]
      exec cp -f ${DRIVER} ${PROJ_DIR}/ip/.
   }

   # Copy the HLS implementation report
   exec cp -rf ${OUT_DIR}/${PROJECT}_project/solution1/impl/report/verilog ${PROJ_DIR}/reports/impl

}

# Close current solution
close_solution

# Close the project
close_project
exit 0
