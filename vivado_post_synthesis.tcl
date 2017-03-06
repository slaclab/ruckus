##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Post-Synthesis Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

# Check for errors during synthesis
set NumErr [llength [lsearch -all -regexp [split [read [open ${SYN_DIR}/runme.log]]] "^ERROR:"]]
if { ${NumErr} != 0 } {
   set errReport [read [open ${SYN_DIR}/runme.log]]
   set errReport [split ${errReport} "\n"]
   set listErr ""
   foreach msg ${errReport} {
      if { [string match {*ERROR:*} ${msg}] == 1 } {
         regexp {([^\]]+):?(/.*)} "${msg}" trim1 trim2
         set listErr "${listErr}\n${trim1}"       
      }
   }   
   puts "\n\n\n\n\n********************************************************"
   puts "********************************************************"
   puts "********************************************************"   
   puts "The following error(s) were detected during synthesis:${listErr}"
   puts "********************************************************"
   puts "********************************************************"
   puts "********************************************************\n\n\n\n\n"     
   exit -1
}

# Target specific post_synthesis script
SourceTclFile ${VIVADO_DIR}/post_synthesis.tcl
