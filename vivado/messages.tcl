##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/messages.tcl
# \brief This script modifies the Vivado messaging configurations

########################################################
## Get variables and Custom Procedures
########################################################

source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Get the value of all the timing ignore flags
set tigAll   [expr {[info exists ::env(TIG)]       && [string is true -strict $::env(TIG)]}]
set tigSetup [expr {[info exists ::env(TIG_SETUP)] && [string is true -strict $::env(TIG_SETUP)]}]
set tigHold  [expr {[info exists ::env(TIG_HOLD)]  && [string is true -strict $::env(TIG_HOLD)]}]
set tigPulse [expr {[info exists ::env(TIG_PULSE)] && [string is true -strict $::env(TIG_PULSE)]}]

if { ${tigSetup} == 1 ||
     ${tigHold}  == 1 ||
     ${tigPulse} == 1 ||
     ${tigAll}   == 1 } {
   set notTig false
} else {
   set notTig true
}

########################################################
## Message Suppression
########################################################

# Messages Suppression: INFO
set_msg_config -suppress -id {Synth 8-256}; # SYNTH: Done synthesizing module
set_msg_config -suppress -id {Synth 8-113}; # SYNTH: Binding component instance 'RTL_Inst' to cell 'PRIMITIVE'
set_msg_config -suppress -id {Synth 8-226}; # SYNTH: Default block is never used
set_msg_config -suppress -id {Synth 8-312}; # SYNTH: Ignoring "unsynthesizable construct" message due to assert error checking
set_msg_config -suppress -id {Synth 8-4472};# SYNTH: Detected and applied attribute shreg_extract = no
set_msg_config -suppress -id {Synth 8-4480};# SYNTH: BRAM: Providing additional output register may help in improving timing
set_msg_config -suppress -id {Synth 8-3331};# SYNTH: Unconnected port
set_msg_config -suppress -id {Synth 8-3332};# SYNTH: Sequential element is unused and will be removed from module
set_msg_config -suppress -id {Synth 8-5544};# SYNTH: ROM wont be mapped to block ram
set_msg_config -suppress -id {Synth 8-5545};# SYNTH: ROM wont be mapped to block ram
set_msg_config -suppress -id {Synth 8-5546};# SYNTH: ROM wont be mapped to block ram
set_msg_config -suppress -id {Opt   31-422};# SYNTH: BRAM changed from INDEPENDENT to COMMON

set_msg_config -suppress -id {HDL 9-2216};  # SIM: Analyzing SystemVerilog file into library work
set_msg_config -suppress -id {HDL 9-1061};  # SIM: Parsing VHDL file
set_msg_config -suppress -id {Runs 36-5};   # SIM: Copied auxiliary file
set_msg_config -suppress -id {VRFC 10-163}; # SIM: Analyzing VHDL file
set_msg_config -suppress -id {VRFC 10-165}; # SIM: Analyzing VERILOG file
set_msg_config -suppress -id {Simtcl 6-16}; # SIM: Simulation closed
set_msg_config -suppress -id {Simtcl 6-17}; # SIM: Simulation restarted

set_msg_config -suppress -id {Constraints 18-4434}; # XDC: Using a LOC constraint to assign the placement of a Global Clock Buffer can result in sub-optimal placement results in UltraScale

set_msg_config -suppress -id {Drc 23-20};     # DRC: writefirst - Synchronous clocking for BRAM
set_msg_config -suppress -id {DRC CHECK-3};   # DRC: Report rule limit reached
set_msg_config -suppress -id {DRC DPIP-1};    # DRC: Input pipelining for DSP
set_msg_config -suppress -id {DRC DPOP-1};    # DRC: PREG Output pipelining for DSP
set_msg_config -suppress -id {DRC DPOP-2};    # DRC: MREG Output pipelining for DSP
set_msg_config -suppress -id {DRC LOCE-1};    # DRC: Pblock ranges contradict LOC constraints
set_msg_config -suppress -id {DRC RTSTAT-10}; # DRC: No routable loads:
set_msg_config -suppress -id {DRC REQP-1839}; # DRC: RAMB36 async control check
set_msg_config -suppress -id {DRC REQP-1840}; # DRC: RAMB36 async control check
set_msg_config -suppress -id {Drc REQP-1857]};# DRC: RAMB18E2_writefirst - Synchronous clocking for BRAM
set_msg_config -suppress -id {Drc REQP-1858]};# DRC: RAMB36E2_writefirst - Synchronous clocking for BRAM
set_msg_config -suppress -id {DRC REQP-181};  # DRC: writefirst: Synchronous clocking is detected for BRAM
set_msg_config -suppress -id {DRC REQP-52};   # DRC: connects_GTGREFCLK_ACTIVE

set_msg_config -suppress -id {BD 41-434}; # Block Design: Could not find an IP with XCI file by name

## Check for version 2015.3 (or older)
if { [VersionCompare 2015.3] <= 0 } {
   set_msg_config -suppress -id {Synth 8-637}; # SYNTH: synthesizing blackbox instance .... [required for upgrading {Synth 8-63} to an ERROR]
   set_msg_config -suppress -id {Synth 8-638}; # SYNTH: synthesizing module .... [required for upgrading {Synth 8-63} to an ERROR]
}

# Messages Suppression: WARNING
set_msg_config -suppress -id {Designutils 20-1318};# DESIGN_UTILS: Multiple VHDL modules with the same architecture name
set_msg_config -suppress -id {Common 17-301};# DESIGN_INIT: Failed to get a license: Internal_bitstream
set_msg_config -suppress -id {Pwropt 34-142};# Post-Place Power Opt: power_opt design has already been performed within this design hierarchy. Skipping
set_msg_config -suppress -id {Common 17-1361};# The existing rule will be replaced.
set_msg_config -suppress -id {Vivado 12-4430};# Overriding default DRC messaging
set_msg_config -suppress -id {Vivado 12-1790};# IP core licensing warning
set_msg_config -suppress -id {Vivado 12-3645};# Adding multiple files in a single "add_files" command
set_msg_config -suppress -id {Project 1-486};# unresolve non-primitive black box cell when using DCP files
set_msg_config -suppress -id {Project 1-560};# unresolve non-primitive black box cell when using DCP files
set_msg_config -suppress -id {Designutils 20-1307};# https://www.xilinx.com/support/answers/54842.html
set_msg_config -suppress -id {filemgmt 56-12};# .ELF/.BMM already added to project

# Messages Suppression: CRITICAL_WARNING
set_msg_config -suppress -id {Vivado 12-5470};  # Using .DCP instead of .XCI
set_msg_config -suppress -id {Project 1-841};   # Using .DCP instead of .XCI
set_msg_config -suppress -id {Project 1-863};   # Using .DCP instead of .XCI
set_msg_config -suppress -id {Project 1-840};   # Using .DCP instead of .XCI

########################################################
## Modifying WARNING messaging
########################################################

# Messages: Change from WARNING to INFO
set_msg_config -id {Timing 38-3}        -new_severity INFO;# User defined clocks are common and should be info, not warning.
set_msg_config -id {Synth 8-3848}       -new_severity INFO;# SYNTH: Signal does not have driver
set_msg_config -id {Synth 8-3936}       -new_severity INFO;# SYNTH: BRAM byte write enable found unconnected
set_msg_config -id {Synth 8-5733}       -new_severity INFO;# SYNTH: ignoring attributes on constant declaration STRING_ROM_C
set_msg_config -id {Synth 8-5858}       -new_severity INFO;# SYNTH: Abstract Data Type (record/struct) for this pattern/configuration is not supported. This will most likely be implemented in registers
set_msg_config -id {Constraints 18-550} -new_severity INFO;# Design Init: Could not drive constant because not directly connected to top level port
set_msg_config -id {Vivado 12-1008}     -new_severity INFO;# Design Init: No clocks found for command
set_msg_config -id {Power 33-332}       -new_severity INFO;# Route: Found switching activity that implies high-fanout reset nets being asserted for excessive periods of time which may result in inaccurate power analysis.

# Messages: Change from WARNING to ERROR
set_msg_config -id {Synth 8-3512}     -new_severity ERROR;# SYNTH: Assigned value in logic is out of range
set_msg_config -id {VRFC 10-664}      -new_severity ERROR;# SIM:   expression has XXX elements ; expected XXX
set_msg_config -id {filemgmt 20-1318} -new_severity ERROR;# FILEMGMT: Duplicate entities/files found in the same library
set_msg_config -id {IP_Flow 19-1663}  -new_severity ERROR;# IP_FLOW: Duplicate IP found
set_msg_config -id {IP_Flow 19-11772} -new_severity ERROR;# IP_FLOW: Failed to register IP shared directory path

## Check for version 2015.3 (or older)
if { [VersionCompare 2015.3] <= 0 } {
   set_msg_config -id {Synth 8-63}   -new_severity ERROR;# SYNTH: RTL assertion
}

# Messages: Change from WARNING to CRITICAL_WARNING
set_msg_config -id {Vivado 12-508}     -new_severity "CRITICAL WARNING";# XDC: No pins matched
set_msg_config -id {Vivado 12-507}     -new_severity "CRITICAL WARNING";# XDC: No netname matched
set_msg_config -id {Vivado 12-627}     -new_severity "CRITICAL WARNING";# XDC: No clock matched
set_msg_config -id {Project 1-498}     -new_severity "CRITICAL WARNING";# XDC: One or more constraints failed evaluation while reading constraint file
set_msg_config -id {Synth 8-3330}      -new_severity "CRITICAL WARNING";# SYNTH: an empty top module top detected
set_msg_config -id {Synth 8-3919}      -new_severity "CRITICAL WARNING";# SYNTH: Null Assignment in logic
set_msg_config -id {Synth 8-153}       -new_severity "CRITICAL WARNING";# SYNTH: Case statement has an input that will never be executed
set_msg_config -id {Synth 8-3295}      -new_severity "CRITICAL WARNING";# SYNTH: Tying undriven pin to a constant
set_msg_config -id {Synth 8-5835}      -new_severity "CRITICAL WARNING";# SYNTH: Resources of type BRAM have been overutilized. Will try to implement using LUT-RAM.
set_msg_config -id {Route 35-328}      -new_severity "CRITICAL WARNING";# IMPL: Router estimated timing not met

########################################################
## Modifying CRITICAL_WARNING messaging
########################################################

# Messages: Change from CRITICAL_WARNING to WARNING
set_msg_config -id {Vivado 12-4430} -new_severity {Warning};# Modifying [get_drc_checks REQP-52]
set_msg_config -id {Vivado 12-1387} -new_severity {Warning};# No valid object(s) found for set_false_path constraint
set_msg_config -id {BD 41-968}      -new_severity {Warning};# No associated to any clock port on a block design bus

# DRC: Change from CRITICAL_WARNING to WARNING
set_property SEVERITY {Warning} [get_drc_checks NSTD-1];  # DRC: I/O standard (IOSTANDARD) value 'DEFAULT', instead of a user assigned specific value

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Vivado 12-1411} -new_severity ERROR;# SYNTH: Cannot set LOC property of differential pair ports
set_msg_config -id {HDL 9-806}      -new_severity ERROR;# SYNTH: Syntax error near *** (example: missing semicolon)
set_msg_config -id {Opt 31-80}      -new_severity ERROR;# IMPL: Multi-driver net found in the design
set_msg_config -id {Route 35-14}    -new_severity ERROR;# IMPL: Multi-driver net found in the design
set_msg_config -id {AVAL-46}        -new_severity ERROR;# DRC: MMCM's (or PLL's) VCO frequency out of range
if { ${notTig} } {
   # set_msg_config -id {Route 35-39}    -new_severity ERROR;# IMPL: The design did not meet timing requirements
   set_msg_config -id {Timing 38-282}  -new_severity ERROR;# IMPL: The design failed to meet the timing requirements
}

########################################################
## Modifying ERROR messaging
########################################################

# Messages: Change from ERROR to WARNING
set_msg_config -id {Common 17-356} -new_severity {Warning};# Failed to install all user apps.

# DRC: Change from ERROR to WARNING
set_property SEVERITY {Warning} [get_drc_checks {REQP-52}]; # DRC: using the GTGREFCLK port on a MGT  (GTP7 & GTX7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-44}]; # DRC: using the GTGREFCLK port on a MGT  (GTH7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-46}]; # DRC: using the GTGREFCLK port on a QPLL (GTH7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-56}]; # DRC: using the GTGREFCLK port on a QPLL (GTX7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-49}]; # DRC: using the GTGREFCLK port on a QPLL (GTP7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-1753}]; # DRC: using the GTGREFCLK port on CPLL (GTH7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-1751}]; # DRC: using the GTGREFCLK port on a QPLL (GTHE3_COMMON)
set_property SEVERITY {Warning} [get_drc_checks {UCIO-1}];  # DRC: using the XADC's VP/VN ports

########################################################
# Check if Multi-Driven Nets are allowed
########################################################
if { [info exists ::env(ALLOW_MULTI_DRIVEN)] != 1 || $::env(ALLOW_MULTI_DRIVEN) == 0 } {
    set_msg_config -id {Synth 8-6859} -new_severity ERROR;  # SYNTH: multi-driven pin
    set_msg_config -id {Synth 8-3352} -new_severity ERROR;  # SYNTH: multi-driven net
    set_msg_config -id {MDRV-1}       -new_severity ERROR;  # DRC: multi-driven net
} else {
    set_msg_config -id {Synth 8-6859} -new_severity INFO;   # SYNTH: multi-driven pin
    set_msg_config -id {Synth 8-3352} -new_severity INFO;   # SYNTH: multi-driven net
    set_msg_config -id {MDRV-1}       -new_severity INFO;   # DRC: multi-driven net
}

########################################################
# Check if Un-Driven Nets are **NOT** allowed
########################################################
if { [info exists ::env(ALLOW_UN_DRIVEN)] != 1 || $::env(ALLOW_UN_DRIVEN) == 1 } {
    set_msg_config -id {Synth 8-3848} -new_severity "CRITICAL WARNING"; # SYNTH: un-driven net
} else {
    set_msg_config -id {Synth 8-3848} -new_severity ERROR; # SYNTH: un-driven net
}

########################################################
# Check if inferred latch are **NOT** allowed
########################################################
if { [info exists ::env(ALLOW_LATCH)] != 1 || $::env(ALLOW_LATCH) == 1 } {
    set_msg_config -id {Synth 8-327} -new_severity "CRITICAL WARNING"; # SYNTH: Inferred latch
} else {
    set_msg_config -id {Synth 8-327} -new_severity ERROR; # SYNTH: Inferred latch
}

###################################################################
# Check if "Signal not in the sensitivity list" are **NOT** allowed
###################################################################
if { [info exists ::env(ALLOW_PARTIAL_SENSE_LIST)] != 1 || $::env(ALLOW_PARTIAL_SENSE_LIST) == 1 } {
    set_msg_config -id {Synth 8-614} -new_severity "CRITICAL WARNING";# SYNTH: Signal not in the sensitivity list
} else {
    set_msg_config -id {Synth 8-614} -new_severity ERROR;# SYNTH: Signal not in the sensitivity list
}

########################################################
# Target specific messages script
########################################################

SourceTclFile ${VIVADO_DIR}/messages.tcl
