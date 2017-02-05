#!/usr/bin/python
#-----------------------------------------------------------------------------
# Description: 
#       This script is designed to parse the Vivado "write_vhdl -mode synth_stub"
#       output file back into the user friendly record types.
#
# Here's an example of what the "write_vhdl -mode synth_stub" output file looks like:
#        entity DcpCore is
#          Port ( 
#            \dataIn[1][tData]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
#            \dataIn[0][tData]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
#            \dataout[1][toggle]\ : out STD_LOGIC;
#            \dataout[1][tData]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
#            \dataout[0][toggle]\ : out STD_LOGIC;
#            \dataout[0][tData]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
#            led : out STD_LOGIC_VECTOR ( 3 downto 0 );
#            clkP : in STD_LOGIC;
#            clkN : in STD_LOGIC
#          );
#
# Here's an example of what this script outputs after reading in this Vivado file:
#        U_Core : entity work.DcpCore
#          port map (
#            \dataIn[1][tData]\ =>     dataIn(1).tData ,
#            \dataIn[0][tData]\ =>     dataIn(0).tData ,
#            \dataout[1][toggle]\ =>     dataout(1).toggle ,
#            \dataout[1][tData]\ =>     dataout(1).tData ,
#            \dataout[0][toggle]\ =>     dataout(0).toggle ,
#            \dataout[0][tData]\ =>     dataout(0).tData ,
#            led =>    led ,
#            clkP =>    clkP ,
#            clkN =>    clkN );
#
# Note: I recommend running EMACS beatify afterwards.
#
#-----------------------------------------------------------------------------
# This file is part of 'LCLS2 AMC Carrier Firmware'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'LCLS2 AMC Carrier Firmware', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------


import os
import sys
import re

def proc(line):
    # Get the port name
    port = line.split(":")[0]
    
    # check for record type
    if re.search(r'\\', line):
        retVar = (port + "=> ")    
        # strip off the \ char
        convt  = port.replace('\\','')
        # strip off the ] char
        convt  = convt.replace(']','')
        # separate the delimiters
        convt = convt.split("[")
        # loop through the array
        for i in range(len(convt)):
            # strip off the space char
            convt[i] = convt[i].replace(' ','')        
            # Check for first element
            if (i==0):
                retVar += convt[0]
            else: 
                # Check if array index
                if convt[i].isdigit():
                    retVar += ('('+convt[i]+')')
                else: 
                    retVar += ('.'+convt[i])
    else:
        retVar = (port + "=> " + port.replace(' ','') )
        
    # Check if last port mapping
    if re.search(r';', line):
        retVar += ",\n"
    else:
        retVar += ");\n"
        
    # Return the results    
    return retVar


def vho(arg):
    # common define
    entity  = ''
    line    = ''
    fname = arg.replace('.vhd','') + '.vho'

    # Open the input/output files
    ifd = open(arg)
    ofd = open(fname, 'w')  
    
    # strip out the input files header
    while (not re.search('Port', line)):
        line = ifd.readline()
        if re.search('entity', line):
            entity = line.replace('entity','')
            entity = entity.replace('is','')
            entity = entity.replace(' ','')
            entity = entity.replace('\n','')
            
    # Output file header
    ofd.write('U_Core: entity work.'+entity+'\n')
    ofd.write('  port map (\n') 

    # Loop through the ports
    line = ifd.readline()
    while (not re.match("  \);", line)):
        # Process the line and write to file
        ofd.write(proc(line))
        # Read the file
        line = ifd.readline()  
      
    # Close the files
    ifd.close()
    ofd.close()
    
    # # Print the output files
    # os.system('cat ' + fname)
    
if __name__ == '__main__':
    vho(sys.argv[1])
