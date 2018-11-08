##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado_hls_proc.tcl
# \brief This script contains all the custom TLC procedures for Vivado HLS

###############################################################
#### General Functions ########################################
###############################################################

## Refreshes the Vivado HLS project
proc VivadoRefresh { vivadoHlsProject } {
   close_project
   open_project ${vivadoHlsProject}
}

## Custom TLC source function
proc SourceTclFile { filePath } {
   if { [file exists ${filePath}] == 1 } {
      source ${filePath}
      return true;
   } else {
      return false;
   }
}

## Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}

## Check for Vivado HLS versions that are supportted by ruckus
proc HlsVersionCheck { } {
   set VersionNumber [version -short]
   if { ${VersionNumber} == 2014.2 } {
      puts "\n\n****************************************************************"
      puts "Vivado_HLS Version = ${VersionNumber} is not support in this build system."
      puts "****************************************************************\n\n" 
      return -1
   } else {
      return 0
   }
}

## Check if the Synthesize is completed
proc PrintBuildComplete { filename } {
   puts "\n\n********************************************************"
   puts "The new .dcp file is located here:"
   puts ${filename}
   puts "********************************************************\n\n" 
}
