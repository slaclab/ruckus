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

# Remove old build
exec rm -rf ${SYN_DIR}

# Create new build directories
exec mkdir ${SYN_DIR}
exec mkdir ${SYN_DIR}/reports
exec mkdir ${SYN_DIR}/svf

# Hard coded to 4
set_host_option -max_cores 4

# Include DesignWare synthetic library
set synthetic_library "dw_foundation.sldb"
source -echo -verbose ${pdk_dir}/scripts/syn_libs.tcl

# Setup milkyway reference library
create_mw_lib -technology $milkyway_tech -mw_reference_library $milkyway_ref_lib "$design"
open_mw_lib "$design"

# Setup TLU Plus files
lappend search_path $pdk_dir/Back_End/milkyway/tcb013ghp_211a/techfiles/
set_tlu_plus_files -tech2itf_map $tluplus_tech2itf_map_file -max_tluplus $max_tluplus_file
check_tlu_plus_files

# Set the set_svf path
set_svf ${SYN_DIR}/svf/${design}.svf

# Load the top-level ruckus.tcl
source $::env(PROJ_DIR)/ruckus.tcl

# elaborate the design
elaborate $design
current_design $design

if {[link] == 0} {
  echo “Linking error!”
  exit; # Exits DC if a serious linking problem is encountered
}
if {[check_design] == 0} {
  echo “Check Design error!”
  exit; # Exits DC if a check-design error is encountered
}

# Source script to define different multi-corner scenarios
source -echo -verbose ${pdk_dir}/scripts/syn_corners.tcl

# Source the constraints file
source -echo -verbose  ${PROJ_DIR}/syn/constraints.tcl

# Set fix hold on clocks
set_fix_hold [all_clocks]

# Setup isolated port
set_isolate_ports  [all_outputs] -type inverter -force

# Check the timing
if {[check_timing] == 0} {
  echo “Check Timing error!
  exit; # Exits DC if a check-timing error is encountered
}

# Setup fix multiple port nets
set_fix_multiple_port_nets -all -buffer_constants

# Compile the design
compile_ultra -no_autoungroup

# Turn off svf
set_svf -off

# DC Compiler sets dont_use attribute on tie cells by default. Override this.
remove_attribute [get_lib_cells *:*/TIEL] dont_use
remove_attribute [get_lib_cells *:*/TIEH] dont_use

# Write outputs
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output ${SYN_DIR}/${design}_g.v
write -format ddc -hierarchy -output ${SYN_DIR}/${design}_g.ddc
write_sdf ${SYN_DIR}/${design}_g.sdf
write_sdc ${SYN_DIR}/${design}_g.sdc

# Copy the .sdf and .v to project image directory
exec cp -f ${SYN_DIR}/${design}_g.sdf ${IMAGES_DIR}/${IMAGENAME}.sdf
exec cp -f ${SYN_DIR}/${design}_g.v   ${IMAGES_DIR}/${IMAGENAME}.v

# Generate reports
report_area -nosplit -hierarchy > ${SYN_DIR}/reports/area.rpt
report_timing -nosplit -transition_time -nets -attributes -delay_type max > ${SYN_DIR}/reports/timing.rpt
report_timing -nosplit -transition_time -nets -attributes -delay_type min >> ${SYN_DIR}/reports/timing.rpt
report_power -nosplit -hierarchy > ${SYN_DIR}/reports/power.rpt
report_resources -nosplit -hierarchy > ${SYN_DIR}/reports/resources.rpt
