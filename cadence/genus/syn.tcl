##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Load RUCKUS environment and library
source $::env(RUCKUS_GENUS_DIR)/proc.tcl
source $::env(RUCKUS_GENUS_DIR)/env_var.tcl

source ${RUCKUS_DIR}/cadence/genus/messages.tcl

# Init the global variable
set ::DIR_PATH ""

# Setup local variables
set design  ${DESIGN}
set pdk_dir $::env(PDK_PATH)

# Check for user import.tcl script
if { [file exists ${PROJ_DIR}/syn/import.tcl] == 1 } {
   source ${PROJ_DIR}/syn/import.tcl
} else {

   # Setup super-threading
   set_db max_cpus_per_server $::env(MAX_CORES)
   set_db super_thread_servers "localhost"

   # define tech, operating conditions and cell lef
   set_db library $::env(STD_CELL_LIB)
   set_db operating_condition $::env(OPERATING_CONDITION)
   set_db lef_library $::env(STD_LEF_LIB)

   # Before loading your design, make every block unique
   set init_design_uniquify 1
}

# Load the top-level ruckus.tcl
source $::env(PROJ_DIR)/ruckus.tcl

# Source the constraints file
source ${PROJ_DIR}/syn/compile.tcl

# Check for user export.tcl script
if { [file exists ${PROJ_DIR}/syn/export.tcl] == 1 } {
   source ${PROJ_DIR}/syn/export.tcl
} else {

   # Generate reports
   report_area
   report_qor

   # Export the reports
   report_ple    > ${SYN_OUT_DIR}/reports/ple.rpt
   report area   > ${SYN_OUT_DIR}/reports/area.rpt
   report gates  > ${SYN_OUT_DIR}/reports/gates.rpt
   report timing > ${SYN_OUT_DIR}/reports/timing.rpt
   report power  > ${SYN_OUT_DIR}/reports/power.rpt

   # Prepare design to INNOVUS
   write_design -innovus ${design}

   # Write outputs
   write_hdl  > ${SYN_OUT_DIR}/${design}_g.v
   write_hdl -pg -lec > ${SYN_OUT_DIR}/${design}_pwr.v
   write_hdl -generic > ${SYN_OUT_DIR}/${design}_generic.v
   write_sdf > ${SYN_OUT_DIR}/${design}_g.sdf
   write_sdc > ${SYN_OUT_DIR}/${design}_g.sdc

   # Copy the .sdf, sdc, .v, and reports to project image directory
   exec cp -f ${SYN_OUT_DIR}/${design}_g.sdf ${IMAGES_DIR}/${IMAGENAME}.sdf
   exec cp -f ${SYN_OUT_DIR}/${design}_g.sdc ${IMAGES_DIR}/${IMAGENAME}.sdc
   exec cp -r ${SYN_OUT_DIR}/${design}_g.v   ${IMAGES_DIR}/${IMAGENAME}.v
   exec rm -rf ${IMAGES_DIR}/reports
   exec cp -rf ${SYN_OUT_DIR}/reports ${IMAGES_DIR}/.

   # Create compressed versions of the files due to Github's 100MB limit on git-lfs
   exec gzip -c -f -9 ${SYN_OUT_DIR}/${design}_g.sdf > ${IMAGES_DIR}/${IMAGENAME}.sdf.gz
   exec gzip -c -f -9 ${SYN_OUT_DIR}/${design}_g.sdc > ${IMAGES_DIR}/${IMAGENAME}.sdc.gz
   exec gzip -c -f -9 ${SYN_OUT_DIR}/${design}_g.v   > ${IMAGES_DIR}/${IMAGENAME}.v.gz
}

quit
