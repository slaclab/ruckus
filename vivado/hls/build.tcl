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
   set retVal [catch { cosim_design -O -ldflags ${LDFLAGS} -mflags ${MFLAGS} -argv ${ARGV} -trace_level all -rtl verilog -tool $::env(HLS_SIM_TOOL) }]
   CheckProcRetVal ${retVal} "cosim_design" "vivado/hls/build"
}

# Copy the IP directory to module source tree
if { [file isdirectory ${PROJ_DIR}/ip/] != 1 } {
   exec mkdir ${PROJ_DIR}/ip/
}

# Copy the HLS csynth reports
set csyn_reports [glob "${OUT_DIR}/${PROJECT}_project/solution1/syn/report/*.rpt"]
file copy -force {*}$csyn_reports ${PROJ_DIR}/ip/.

# Export the Design
if { [info exists ::env(SKIP_EXPORT)] == 0 } {

   set retVal [catch { export_design -flow syn -rtl verilog -format ip_catalog }]
   CheckProcRetVal ${retVal} "export_design" "vivado/hls/build"

   # Copy over the .DCP file
   exec cp -f  [exec ls [glob "${OUT_DIR}/${PROJECT}_project/solution1/impl/verilog/project.runs/synth_1/*.dcp"]] ${PROJ_DIR}/ip/${TOP}.dcp

   # Copy the driver to module source tree
   set DRIVER ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip/drivers
   if { [file exist  ${DRIVER}] } {
      set DRIVER ${DRIVER}/[exec ls ${DRIVER}]/src
      set DRIVER [glob ${DRIVER}/*_hw.h]
      exec cp -f ${DRIVER} ${PROJ_DIR}/ip/.
   }

   # Copy the HLS implementation report
   exec cp -f  [exec ls [glob "${OUT_DIR}/${PROJECT}_project/solution1/impl/report/verilog/*.rpt"]] ${PROJ_DIR}/ip/.
}

# Close current solution
close_solution

# Close the project
close_project
exit 0
