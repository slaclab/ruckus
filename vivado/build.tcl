##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/build.tcl
# \brief This script builds the Vivado project in batch mode

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
update_compile_order -quiet -fileset sources_1

########################################################
## Check project configuration for errors
########################################################
if { [CheckPrjConfig sources_1] != true ||
     [CheckPrjConfig sim_1]     != true } {
   exit -1
}

########################################################
## Check if we need to clean up or stop the implement
########################################################
if { [CheckImpl] != true } {
   reset_run impl_1
}

########################################################
## Check if we need to clean up or stop the synthesis
########################################################
if { [CheckSynth] != true } {
   reset_run synth_1
}

########################################################
## Check if we re-synthesis any of the IP cores
########################################################
if {[llength [get_ips]] > 0} {
    BuildIpCores
} else {
    puts "No IP cores found."
}


########################################################
## Target Pre synthesis script
########################################################
source ${RUCKUS_DIR}/vivado/pre_synthesis.tcl

########################################################
## Synthesize
########################################################
set syn_rc [catch {
   if { [CheckSynth] != true } {
      ## Check for DCP only synthesis run
      if { [info exists ::env(SYNTH_DCP)] } {
         SetSynthOutOfContext
      }
      ## Launch the run
      launch_runs synth_1 -jobs $::env(PARALLEL_SYNTH)
      set src_rc [catch {
         wait_on_run synth_1
      } _RESULT]
   }
} _SYN_RESULT]

########################################################
# Check for error return code during synthesis process
########################################################
if { ${syn_rc} } {
   PrintOpenGui ${_SYN_RESULT}
   exit -1
}

########################################################
## Check that the Synthesize is completed
########################################################
if { [CheckSynth printMsg] != true } {
   close_project
   exit -1
}

########################################################
## Target post synthesis script
########################################################
source ${RUCKUS_DIR}/vivado/post_synthesis.tcl

########################################################
## Check if only doing Synthesize
########################################################
if { [info exists ::env(SYNTH_ONLY)] } {
   close_project
   BuildInfo
   exit 0
}

########################################################
## Check if Synthesizen DCP Output
########################################################
if { [info exists ::env(SYNTH_DCP)] } {
   source ${RUCKUS_DIR}/vivado/dcp.tcl
   close_project
   BuildInfo
   exit 0
}

########################################################
## Import static checkpoint
########################################################
if { ${RECONFIG_CHECKPOINT} != 0 } {
   ImportStaticReconfigDcp
}

########################################################
## Implement
########################################################
if { [CheckImpl] != true } {
   launch_runs -to_step write_bitstream impl_1
   set src_rc [catch {
      wait_on_run impl_1
   } _RESULT]
}

########################################################
## Check that the Implement is completed
########################################################
if { [CheckImpl printMsg] != true } {
   close_project
   exit -1
}

########################################################
## Check if there were timing
## or routing errors during implement
########################################################
if { [CheckTiming] != true } {
   close_project
   exit -1
}

########################################################
## Target post route script
########################################################
source ${RUCKUS_DIR}/vivado/post_route.tcl

########################################################
## Export static checkpoint for dynamic partial reconfiguration build
########################################################
if { [VersionCompare 2016.4] >= 0 } {
   if { [get_property PR_FLOW [current_project]] != 0 } {
      ExportStaticReconfigDcp
   }
}

########################################################
## Export partial configuration bit file(s)
########################################################
if { ${RECONFIG_CHECKPOINT} != 0 } {
   if { $::env(GEN_BIN_IMAGE) != 0 } {
      ExportPartialReconfigBin
   }
   ExportPartialReconfigBit
}

########################################################
## Copy the FW image files
########################################################
if { [isVersal] } {
   # Create Versal Output files
   CreateVersalOutputs
} else {
   # Copy the .bit file (and create .mcs)
   CreateFpgaBit
}

########################################################
# Target Post Build script
########################################################
SourceTclFile ${VIVADO_DIR}/post_build.tcl

########################################################
## Close the project and return sucessful flag
########################################################
close_project
exit 0
