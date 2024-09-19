##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

###############################################################
#### Hardware Debugging Functions #############################
###############################################################

## Create a Debug Core Function
proc CreateDebugCore {ilaName} {

   # Check if Vivado 2024.1 or later
   if { [VersionCompare 2024.1] >= 0} {
      # Check if the currently sourced script contains "post_synthesis.tcl"
      if {[string match "*post_synthesis.tcl" [info script]]} {
         puts "\n\n\n\n\n********************************************************"
         puts "vivado/post_synthesis.tcl no longer works with Vivado 2024.1 (or later)"
         puts "Please do the following operations on your post_synthesis.tcl script"
         puts "1) Rename the script from post_synthesis.tcl to pre_opt_run.tcl"
         puts "2) Remove the 'open_run synth_1' TCL command from the script"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      }
   }

   # Delete the Core if it already exist
   delete_debug_core -quiet [get_debug_cores ${ilaName}]

   # Create the debug core
   if { [VersionCompare 2017.2] <= 0 } {
      create_debug_core ${ilaName} labtools_ila_v3
   } else {
      create_debug_core ${ilaName} ila
   }
   set_property C_DATA_DEPTH 1024       [get_debug_cores ${ilaName}]
   set_property C_INPUT_PIPE_STAGES 2   [get_debug_cores ${ilaName}]

   # Force a reset of the implementation
   reset_run impl_1
}

## Sets the clock on the debug core
proc SetDebugCoreClk {ilaName clkNetName} {
   set_property port_width 1 [get_debug_ports  ${ilaName}/clk]
   connect_debug_port ${ilaName}/clk [get_nets ${clkNetName}]
}

## Get Current Debug Probe Function
proc GetCurrentProbe {ilaName} {
   return ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]
}

## Probe Configuring function
proc ConfigProbe {ilaName netName {lsb 0} {msb -1} } {

   # determine the probe index
   set probeIndex ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]

   # get the list of netnames
   set probeNet [lsort -increasing -dictionary [get_nets ${netName}]]

   # Check if using range of values
   if { ${msb} > -1 } {
      set probeNet [lrange ${probeNet} ${lsb} ${msb}]
   }

   # calculate the probe width
   set probeWidth [llength ${probeNet}]

   # set the width of the probe
   set_property port_width ${probeWidth} [get_debug_ports ${probeIndex}]

   # connect the probe to the ila module
   connect_debug_port ${probeIndex} ${probeNet}

   # increment the probe index
   create_debug_port ${ilaName} probe
}

## Write the port map file
proc WriteDebugProbes {ilaName {filePath ""}} {

   # Delete the last unused port
   delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

   # Check if write_debug_probes is support
   if { [VersionCompare 2017.2] <= 0 } {
      # Write the port map file
      write_debug_probes -force ${filePath}
   } else {
      # Check if not empty string
      if { ${filePath} != "" } {
         puts "\n\n\n\n\n********************************************************"
         puts "WriteDebugProbes(): Vivado's 'write_debug_probes' procedure has been deprecated in 2017.3"
         puts "Instead the debug_probe file will automatically get copied in the ruckus/system_vivado.mk COPY_PROBES_FILE() function"
         puts "********************************************************\n\n\n\n\n"
      }
   }
}
