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

# Check if we are suppressing messages
if { [expr {[info exists ::env(SUPRESS_MSG)]       && [string is true -strict $::env(SUPRESS_MSG)]}] } {
   source ${RUCKUS_DIR}/cadence/genus/messages.tcl
}

# Init the global variable
set ::DIR_PATH ""

# Check for user import.tcl script
if { [file exists ${PROJ_DIR}/verilog/import.tcl] == 1 } {
   source ${PROJ_DIR}/verilog/import.tcl
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

   # Allow for VHDL real type
   set_db hdl_enable_real_support true

   # Prevent optimization from removing init
   set_db optimize_constant_0_flops false
   set_db optimize_constant_1_flops false

}

# Load the top-level ruckus.tcl
source $::env(PROJ_DIR)/ruckus.tcl

# Check for user compile.tcl script
if { [file exists ${PROJ_DIR}/verilog/compile.tcl] == 1 } {
   source ${PROJ_DIR}/verilog/compile.tcl
} else {
   # Allocate number of cores
   set_multi_cpu_usage -local_cpu 8

   # Uniquify multiple instances of the same module, then elaborate
   set init_design_uniquify 1
   elaborate ${PROJECT}

   # Report black boxes / unresolved cells
   check_design -unresolved
}

# Check for user export.tcl script
if { [file exists ${PROJ_DIR}/verilog/export.tcl] == 1 } {
   source ${PROJ_DIR}/verilog/export.tcl
} else {

   # Write generic (technology-independent) Verilog
   exec rm -rf ${IMAGES_DIR}/${PROJECT}.v
   # write_hdl -generic > ${IMAGES_DIR}/${PROJECT}.v
   write_netlist -generic > ${IMAGES_DIR}/${PROJECT}.v
}

quit
