##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/sources.tcl
# \brief This script loads the source code into the Vivado project

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Check if you have write permission
CheckWritePermission

# Check the git version
CheckGitVersion

# Check if image directory doesn't exist
if { [file exists ${IMAGES_DIR}] != 1 } {
   # Make image dir
   exec mkdir ${IMAGES_DIR}
}

# Open the project
source ${RUCKUS_DIR}/vivado/project.tcl
VivadoRefresh ${VIVADO_PROJECT}

# Setup the user IP repo
set_property ip_repo_paths $::env(IP_REPO) [current_project]
update_ip_catalog

########################################################
## Generate the build string
########################################################

GenBuildString "${OUT_DIR}/${VIVADO_PROJECT}.srcs"

########################################################
## Check for change in hash or fwVersion between builds
########################################################
set pathToLog "${OUT_DIR}/${VIVADO_PROJECT}.srcs/BuildInfo.log"

# Generate the GIT SHA-1 string
set gitHash [GetGitHash]

# Generate the Firmware Version string
set fwVersion [GetFwVersion]

# Check if file doesn't exist
if { [expr [file exists ${pathToLog}]] == 0 } {
   reset_run synth_1
} else {

   # Get the previous build info
   set in [open ${pathToLog} r]
   gets ${in} oldGitHash
   gets ${in} oldFwVersion
   close ${in}

   # Compare the old to current
   if { ${oldGitHash}   != ${gitHash} ||
        ${oldFwVersion} != ${fwVersion}} {
      reset_run synth_1
   }
}

# Write the current build info
set out [open ${pathToLog} w]
puts ${out} ${gitHash}
puts ${out} ${fwVersion}
close ${out}

########################################################
## Load the source code
########################################################

# By default, set the Top Level file same as project name
set_property top ${PROJECT} [current_fileset]
# set_property top "glbl"     [get_filesets sim_1]

# If VIVADO_PROJECT_SIM is defined, use it to override the sim_1 top
# (otherwise keep the top set by the target's ruckus.tcl)
if { $::env(VIVADO_PROJECT_SIM) != "" } {
    set_property top ${VIVADO_PROJECT_SIM} [get_filesets sim_1]
}

# Init the global variable
set ::DIR_PATH ""
set ::DIR_LIST ""
set ::IP_LIST  ""
set ::IP_FILES ""
set ::BD_FILES ""

# Load the top-level ruckus.tcl file
loadRuckusTcl ${PROJ_DIR}

# Change to AbsoluteFirst for source, simulation and constraint file sets
if { [get_files -of_objects [get_filesets {sources_1}]] != "" } {
   set_property PATH_MODE AbsoluteFirst [get_files -of_objects [get_filesets {sources_1}]]
}
if { [get_files -of_objects [get_filesets {sim_1}]] != "" } {
   set_property PATH_MODE AbsoluteFirst [get_files -of_objects [get_filesets {sim_1}]]
}
if { [get_files -of_objects [get_filesets {constrs_1}]] != "" } {
   set_property PATH_MODE AbsoluteFirst [get_files -of_objects [get_filesets {constrs_1}]]
}

# Bind the Rogue TCP/SideBand DPI shared library for Vivado xsim co-simulation.
# This MUST run at project-generation time: after the simulation backend
# sources are loaded (so the guard resolves) and before launch_simulation
# generates elaborate.sh. Setting xsim.elaborate.xelab.more_options from the
# xsim.compile.tcl.pre hook is too late -- elaborate.sh is already generated.
# Guarded on the xsim Rogue backends, so it is a no-op for non-Rogue
# projects and for the GHDL/VCS simulation backends. The bound name must match
# LIB in surf's simlink/xsim/Makefile minus the .so suffix (xelab appends .so
# and adds no "lib" prefix), and the built library is staged into the xsim run
# directory by vivado/run/pre/xsim.tcl.
set rogueXsimSrc ""
foreach rogueFile [RogueSimSources xsim] {
   if { [string match {*/xsim/RogueTcpStream.vhd} ${rogueFile}] ||
        [string match {*/xsim/RogueTcpMemory.vhd} ${rogueFile}] ||
        [string match {*/xsim/RogueSideBand.vhd}  ${rogueFile}] } {
      set rogueXsimSrc ${rogueFile}
   }
}
if { ${rogueXsimSrc} != "" } {
   set xelabOpt [get_property {xsim.elaborate.xelab.more_options} [get_filesets sim_1]]
   if { [string first {-sv_lib libRogueSimLinkDpi} ${xelabOpt}] == -1 } {
      set_property -name {xsim.elaborate.xelab.more_options} -value "${xelabOpt} -sv_lib libRogueSimLinkDpi" -objects [get_filesets sim_1]
   }
} else {
   # Drop a token left behind by an earlier generation of this project that did
   # use the xsim backend. The project persists across make targets, so without
   # this an xsim-then-vcs (or xsim-then-ghdl) switch leaves xelab asking for a
   # DPI library that is no longer part of the build. -quiet because the property
   # only exists on the Vivado versions that take the xsim.* naming.
   set xelabOpt [get_property -quiet {xsim.elaborate.xelab.more_options} [get_filesets sim_1]]
   if { [string first {-sv_lib libRogueSimLinkDpi} ${xelabOpt}] != -1 } {
      regsub -all {\s+} [string map {{-sv_lib libRogueSimLinkDpi} {}} ${xelabOpt}] { } xelabOpt
      set_property -name {xsim.elaborate.xelab.more_options} -value [string trim ${xelabOpt}] -objects [get_filesets sim_1]
   }
}

# Check if we can upgrade IP cores
if { $::IP_LIST != "" } {
   foreach ipPntr $::IP_LIST {
      generate_target all [get_ips ${ipPntr}]
      # Build the IP Core
      puts "\nUpgrading ${ipPntr}.xci IP Core ..."
      upgrade_ip [get_ips ${ipPntr}]
      puts "... Upgrade Complete!\n"
      # Check if we need to create the IP_run
      set ipSynthRun ${ipPntr}_synth_1
      if { [get_runs ${ipSynthRun}] != ${ipSynthRun}} {
         create_ip_run [get_ips ${ipPntr}]
      }
   }
}

# Target specific source setup script
SourceTclFile ${VIVADO_DIR}/sources.tcl

# Remove all unused code
if { $::env(REMOVE_UNUSED_CODE) != 0 } {
   RemoveUnsuedCode
}

# Write the DIR list
exec rm -f {${OUT_DIR}/dirList.txt}
set dirList [open ${OUT_DIR}/dirList.txt  w]
if { $::DIR_LIST != "" } {
   foreach dirPntr $::DIR_LIST {
      puts ${dirList} ${dirPntr}
   }
}
close ${dirList}

# Write the IP list
exec rm -f {${OUT_DIR}/ipList.txt}
set ipList [open ${OUT_DIR}/ipList.txt  w]
if { $::IP_FILES != "" } {
   foreach ipPntr $::IP_FILES {
      puts ${ipList} ${ipPntr}
   }
}
close ${ipList}

# Write the BD list
exec rm -f {${OUT_DIR}/bdList.txt}
set bdList [open ${OUT_DIR}/bdList.txt  w]
if { $::BD_FILES != "" } {
   foreach bdPntr $::BD_FILES {
      puts ${bdList} ${bdPntr}
   }
}
close ${bdList}

# Check if this is a dynamic partial reconfiguration build
if { ${RECONFIG_CHECKPOINT} != 0 } {
   # Set the top-level module as "out_of_context"
   set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
}

# Close the project
close_project
