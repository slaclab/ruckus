##############################################################################
## This file is an addition to the 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/xsim.tcl
# \brief This script performs a Vivado XSIM simulation

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

########################################################
## Open the project
########################################################

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Setup project properties
source -quiet ${RUCKUS_DIR}/vivado/properties.tcl

# Setup project messaging
source -quiet ${RUCKUS_DIR}/vivado/messages.tcl

########################################################
## Update the complie order
########################################################
update_compile_order -quiet -fileset sim_1

########################################################
## Check project configuration for errors
########################################################
if { [CheckPrjConfig sim_1] != true } {
   exit -1
}

########################################################
## Prepare simulation and check IP cores
########################################################
generate_target -quiet {simulation} [get_ips]
export_ip_user_files -no_script

########################################################
## Rogue co-sim batch-path env parity. The guard
## + xsc build + -sv_lib injection live in run/pre/xsim.tcl
## (registered by project.tcl); this is belt-and-suspenders
## only for the batch xsim subprocess -- no duplicate build.
########################################################
set rogueSimPath [RogueSimSources xsim]
if { ${rogueSimPath} != "" } {

   # Version lock: the Rogue xsim DPI co-sim requires Vivado 2023.1+ (see
   # vivado/run/pre/xsim.tcl). Fail fast on the "make xsim" batch path, before
   # launch_simulation. Only reached when the co-sim is used, so a non-Rogue
   # xsim project on an older Vivado is unaffected.
   if { [VersionCheck 2023.1] < 0 } {
      exit -1
   }

   # GLIBCXX runtime fix for the batch xsim subprocess: LD_PRELOAD a libstdc++
   # new enough for the co-sim's libzmq (see RoguePreloadLibStdCpp). The GUI
   # path applies the same fix from vivado/run/pre/xsim.tcl.
   RoguePreloadLibStdCpp

   # LD_LIBRARY_PATH parity so a script-launched xsim subprocess
   # finds libRogueTcpStream.so at runtime, mirroring vcs.tcl's
   # setup_env LD_LIBRARY_PATH prepend
   set simOutDir "${OUT_DIR}/${VIVADO_PROJECT}.sim/sim_1/behav/xsim"
   if { [info exists ::env(LD_LIBRARY_PATH)] } {
      set ::env(LD_LIBRARY_PATH) "${simOutDir}:$::env(LD_LIBRARY_PATH)"
   } else {
      set ::env(LD_LIBRARY_PATH) "${simOutDir}"
   }
}

########################################################
## Simulate Process
########################################################
set sim_rc [catch {

   # Set sim properties
   set_property target_simulator XSim [current_project]
   # Only override the sim_1 top when VIVADO_PROJECT_SIM is explicitly defined;
   # otherwise keep the top auto-picked-up from the target's ruckus.tcl
   if { ${VIVADO_PROJECT_SIM} != "" } {
      set_property top ${VIVADO_PROJECT_SIM} [get_filesets sim_1]
   }
   set_property top_lib xil_defaultlib [get_filesets sim_1]

   # Launch the xsim
   launch_simulation

   # Run simulation for time specified
   set VIVADO_PROJECT_SIM_TIME "run ${VIVADO_PROJECT_SIM_TIME}"; # set cmd
   eval ${VIVADO_PROJECT_SIM_TIME}; # run cmd
} _SIM_RESULT]

########################################################
# Target specific XSIM script
########################################################
SourceTclFile ${VIVADO_DIR}/xsim.tcl

########################################################
# Check for error return code during the process
########################################################
if { ${sim_rc} } {
   PrintOpenGui ${_SIM_RESULT}
   exit -1
}
