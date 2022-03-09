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
source $::env(RUCKUS_DC_DIR)/proc.tcl
source $::env(RUCKUS_DC_DIR)/env_var.tcl

# Init the global variable
set ::DIR_PATH ""
ResetSrcFileLists

# Setup local variables
set design  ${DESIGN}
set pdk_dir ${DIG_TECH}

# Set the number of maximum cores
set_host_option -max_cores ${MAX_CORES}

# Check for user import.tcl script
if { [file exists ${PROJ_DIR}/syn/import.tcl] == 1 } {
   source ${PROJ_DIR}/syn/import.tcl
} else {

   # Include DesignWare synthetic library
   set synthetic_library "dw_foundation.sldb"
   source -echo -verbose ${pdk_dir}/scripts/syn_libs.tcl

   # Setup milkyway reference library
   create_mw_lib -technology $milkyway_tech -mw_reference_library $milkyway_ref_lib "$design"
   open_mw_lib "$design"

   # Setup TLU Plus files
   lappend search_path ${TLU_PLUS_FILES}
   set_tlu_plus_files -tech2itf_map $tluplus_tech2itf_map_file -max_tluplus $max_tluplus_file
   check_tlu_plus_files

   # Set the set_svf path
   set_svf ${SYN_OUT_DIR}/svf/${design}.svf
}

# Set the work path directory
define_design_lib WORK -path ${SYN_DIR}/work

# Load the top-level ruckus.tcl
source $::env(PROJ_DIR)/ruckus.tcl

# Source the constraints file
source ${PROJ_DIR}/syn/compile.tcl

# Check for user export.tcl script
if { [file exists ${PROJ_DIR}/syn/import.tcl] == 1 } {
   source ${PROJ_DIR}/syn/export.tcl
} else {

   # Write outputs
   change_names -rules verilog -hierarchy
   write -format verilog -hierarchy -output ${SYN_OUT_DIR}/${design}_g.v
   write -format ddc -hierarchy -output ${SYN_OUT_DIR}/${design}_g.ddc
   write_sdf ${SYN_OUT_DIR}/${design}_g.sdf
   write_sdc ${SYN_OUT_DIR}/${design}_g.sdc

   # Copy the .sdf and .v to project image directory
   exec cp -f ${SYN_OUT_DIR}/${design}_g.sdf ${IMAGES_DIR}/${IMAGENAME}.sdf
   exec cp -f ${SYN_OUT_DIR}/${design}_g.v   ${IMAGES_DIR}/${IMAGENAME}.v

   # Create compressed versions of the files due to Github's 100MB limit on git-lfs
   exec gzip -c -f -9 ${SYN_OUT_DIR}/${design}_g.sdf > ${IMAGES_DIR}/${IMAGENAME}.sdf.gz
   exec gzip -c -f -9 ${SYN_OUT_DIR}/${design}_g.v   > ${IMAGES_DIR}/${IMAGENAME}.v.gz

   # Generate reports
   report_area -nosplit -hierarchy > ${SYN_OUT_DIR}/reports/area.rpt
   report_timing -nosplit -transition_time -nets -attributes -delay_type max > ${SYN_OUT_DIR}/reports/timing.rpt
   report_timing -nosplit -transition_time -nets -attributes -delay_type min >> ${SYN_OUT_DIR}/reports/timing.rpt
   report_power -nosplit -hierarchy > ${SYN_OUT_DIR}/reports/power.rpt
   report_resources -nosplit -hierarchy > ${SYN_OUT_DIR}/reports/resources.rpt

   exit
}
