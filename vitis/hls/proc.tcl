##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vitis/hls/proc.tcl
# \brief This script contains all the custom TLC procedures for Vitis HLS

###############################################################
#### General Functions ########################################
###############################################################

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

## Check for Vitis HLS versions that are supportted by ruckus
proc HlsVersionCheck { } {
   set VersionNumber [version -short]
   if { ${VersionNumber} < 2021.1 } {
      puts "\n\n****************************************************************"
      puts "Vitis_HLS Version = ${VersionNumber} is not support in this build system."
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

## Check if the failed operation
proc CheckProcRetVal { retVal procType tclScript} {
   if {$retVal} {
      puts "\n\n\n\n\n********************************************************"
      puts "********************************************************"
      puts "********************************************************"
      puts "Failed ${procType} in submodule/ruckus/${tclScript}!!!"
      puts "Execute 'make gui' to open up GUI and evaluate error messages"
      puts "********************************************************"
      puts "********************************************************"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
}

## Modifies the export's IP .ZIP file to add support for all FPGA device families
proc ComponentXmlAllFamilySupport { } {
   # Over the .ZIP file and decompress it
   exec rm -rf $::env(OUT_DIR)/ip
   exec mkdir $::env(OUT_DIR)/ip
   exec unzip $::env(OUT_DIR)/$::env(PROJECT)_project/solution1/impl/ip/*.zip -d $::env(OUT_DIR)/ip

   # open the files
   set in  [open $::env(OUT_DIR)/ip/component.xml r]
   set out [open $::env(OUT_DIR)/ip/component.temp  w]

   # Get the top level name
   set TOP [get_top]

   # Define the old and new string
   set XIL_FAMILY "\
   <xilinx:family xilinx:lifeCycle=\"Production\">artix7</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">kintex7</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">virtex7</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">zynq</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">kintexu</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">virtexu</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">kintexuplus</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">virtexuplus</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">virtexuplusHBM</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">zynquplus</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">zynquplusRFSOC</xilinx:family>\n\
   <xilinx:family xilinx:lifeCycle=\"Production\">versal</xilinx:family>\
   "

   # Find and replace the "xilinx:family" parameter
   while { [eof ${in}] != 1 } {
      gets ${in} line
      if { [string match "*xilinx:family*" ${line}] == 1 } {
         puts ${out} ${XIL_FAMILY}
      } else {
         puts ${out} ${line}
      }
   }

   # Close the files
   close ${in}
   close ${out}

   # over-write the existing file
   exec mv -f $::env(OUT_DIR)/ip/component.temp $::env(OUT_DIR)/ip/component.xml

   # Compress the modify IP directory to the target's image directory
   exec bash -c "cd $::env(OUT_DIR)/ip; zip -r $::env(PROJ_DIR)/ip/$::env(PROJECT).zip *"
}
