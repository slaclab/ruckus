# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

# ------------------------------------------------------------------------------
'''
  Creates either a copy or an augmented copy of the original zip file. This
  is moved from the workspace (which may or may not be saved to git),
  and placed in a directory of the user's choosing.
'''
# ------------------------------------------------------------------------------

from .version import Version
import argparse
import tempfile
import shutil
import subprocess
import os
import sys
from types import SimpleNamespace

dir = os.path.split(__file__)[0] + '../'
sys.path.append(dir)

# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Ip:
    """
    Augments the usually single FPGA in the component.xml file with a family of
    FPGAs, creating a new .zip file
    """
    @staticmethod
    def add_arguments(parser):
        """
        Adds the arguments needed to configure the IP creator

        Args:
             parser:  The parser to add the arguments to
        """
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    def __init__(self, dir, name, family, cmp_dir, info):
        """
        The IP creator's constructor

        Args:
             dir:              The output directory
             name:             The output zip file's name (optional)
             family:           The family of permissible FPGAs
             cmp_dir:          The component directory, i.e. where to look
                               for the original .zip file which contains
                               component.xml

             info:             Contains general information about the component
        """
        # ----------------------------------------------------
        # Define all the input pieces
        # These can be used to provide defaults for the output
        # ----------------------------------------------------
        # Keep track of the component directory and the component name
        self.cmp_dir = cmp_dir
        self.cmp_name = info.cmp_name
        self.top_level = info.hls_top_level

        # Locate the component.xml and <top_level>.zip files
        self.hls_cmp_dir = os.path.realpath(os.path.join(self.cmp_dir,
                                                         self.cmp_name))
        self.hls_impl_dir = os.path.join(self.hls_cmp_dir, 'hls', 'impl')
        self.hls_ip_dir = os.path.join(self.hls_impl_dir, 'ip')
        self.hls_zip = os.path.join(self.hls_cmp_dir,
                                    info.hls_top_level) + '.zip'

        # -------------
        # Output pieces
        # -------------

        if name:
            namdir, namext = os.path.split(name)
        else:
            namext = None

        if not dir:
            print("ERROR: Ip must specify an output directory")
            return
        else:
            dir = os.path.expandvars(dir)

        if not dir:
            print("ERROR:  No output directory provided in"
                  f"        {dir}")
            self.status = -1
            return

        if not namext:
            # Default to the component name
            namext = info.cmp_name

        map = { 'vitis' : SimpleNamespace (version = Version.version),
                'cmp'   : SimpleNamespace (name    =   info.cmp_name) }
        # Expand the symbolics. These are the Vitis Version and component name
        dir = dir.format_map (map)
        namext = namext.format_map (map)

        # The output project IP directory and file
        self.prj_ip_dir = os.path.realpath(os.path.expandvars(dir))
        self.prj_ip_zip = os.path.expandvars(
            os.path.join(self.prj_ip_dir, namext) )

        ext = os.path.splitext (self.prj_ip_zip)[1]
        # To do
        if not ext:
            self.prj_ip_zip += '.zip'


        exists = os.path.isfile(self.hls_zip)
        if not exists:
            self.xil_family = None
            self.family = None
            self.msg = (
                '''ERROR: The original HLS zip file not found, possibly you have not run --syn and --package''')

            self.status = -1
            return

        if family:
            self.family = family
        else:
            self.family = (
                "artix7,kintex7,virtex7,zynq,kintexu,virtexu,kintexuplus,"
                "virtexuplus,virtexuplusHBM,zynquplus,zynquplusRFSOC,versal")

        self.xil_family = self.get_xil_family(self.family)
        self.msg = None
        self.status = 0
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def get_xil_family(family):

        xil_family = ""
        if family:
            families = family.split(',')
            for f in families:
                xil_family += '<xilinx:family xilinx:lifeCycle="Production">' + f + '</xilinx:family>\n'
        else:
            xil_family = """
<xilinx:family xilinx:lifeCycle="Production">artix7</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">kintex7</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtex7</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">zynq</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">kintexu</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtexu</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">kintexuplus</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtexuplus</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtexuplusHBM</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">zynquplus</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">zynquplusRFSOC</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">versal</xilinx:family>
"""
        return xil_family
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    def print(self, printer, verbose):
        printer.itemPlain("Ip .zip", self.prj_ip_zip)

        if verbose or self.msg:
            printer.itemPlain("HLS.zip", self.hls_zip)

        if verbose and self.family:
            margin = printer.m + printer.i
            available = printer.s - margin
            beg = 0
            cnt = len(self.family)
            caption = "   .families"
            limit = available
            while True:
                end = beg + limit
                if end < cnt:
                    end = beg + self.family[beg:end].rfind(',')
                    if end == -1:
                        end = cnt
                else:
                    end = cnt
                printer.itemPlain(caption, self.family[beg:end+1])

                if end >= cnt:
                    break
                caption = ''
                beg = end+1

        if self.msg:
            printer.itemPlain('', self.msg, '*')

        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def execute(self, printer, verbose):

        if self.status:
            return self.status

        # --------------------------------------
        # Ensure the ip project directory exists
        # --------------------------------------
        if not os.path.exists(self.prj_ip_dir):
            os.system(f'mkdir -p {self.prj_ip_dir}')
        elif os.path.exists(self.prj_ip_zip):
            # Remove the existing file
            os.remove(self.prj_ip_zip)

        # ------------------------------------------------------
        # Check if we wish to augment the xilinx family of FPGAs
        # ------------------------------------------------------
        if self.family:

            # Make a temporary directory to hold the unzip contents
            unzip_dir = tempfile.TemporaryDirectory()
            unzip_cmd = ['unzip', self.hls_zip, '-d', unzip_dir.name]
            with subprocess.Popen(unzip_cmd,
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT,
                                  text=True,
                                  bufsize=1) as process:
                if verbose:
                    for line in process.stdout:
                        print(line, end='')
                process.wait()

                # -------------------------------------------
                # Generate the file path of the component.xml
                # -------------------------------------------
                cmp_xml = os.path.join(unzip_dir.name, 'component.xml')
                exists = os.path.isfile(cmp_xml)
                if not exists:
                    self.msg = "Nonexistent xml file"
                    return -1

                # -----------------------------------------------
                # Tried 2 methods, a memory and an auxiliary file
                # -----------------------------------------------
                if True:
                    self.augment_family_memory(unzip_dir.name,
                                               cmp_xml,
                                               printer,
                                               verbose)
                else:
                    self.augment_family_memory_file(unzip_dir.name,
                                                    cmp_xml,
                                                    printer,
                                                    verbose)
        else:
            # -----------------------------------------------------------
            # Just a straight copy from the hls directory -> ip directory
            # -----------------------------------------------------------
            shutil.copy(self.hls_zip, self.prj_ip_zip)

        return 0
    # -------------------------------------------------------------------------


    # -------------------------------------------------------------------------
    def augment_family_memory(self, unzip_dirname, cmp_xml, printer, verbose):
        """
        Augments the permissible XILINX FPGA family using an in memory technique

        Args:
           unzip_dirname:  The directory containing the unzipped files
           cmp_xml      :  The component.xml file to augment
           printer      :  Reports any output
           verbose      :  The verbose output

        Reads the entire file into memory, clears the original file, then
        reads it line by line, augmenting with the new FPGA families as
        necessary, writing it to the original file, essentially replacing it
        with the augmented contents.

        The advantage of this method is its simplicity with the downside that
        the memory usage may be high if the file is large. This is generally
        not the case for the component.xml files, typically around 100KBytes.
        """
        # --------------------------------------------------------------------------

        # --------------------
        # Read the entire file
        # --------------------
        with open(cmp_xml, 'r+') as file:
            lines = file.readlines()

            # -----------------------
            # Clear the original file
            # -----------------------
            file.seek(0)

            # -------------------------
            # Add the new FPGA families
            # -------------------------
            for line in lines:
                if 'xilinx:family' in line:
                    file.write(self.xil_family)
                else:
                    file.write(line)

        # --------------------------------------------------------
        # Recursively zip the previously unzipped file, only this
        # time with the augmented FPGA families.
        # --------------------------------------------------------
        status = self.rezip(self.prj_ip_zip,
                            unzip_dirname,
                            printer,
                            verbose)
        return status
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def augment_family_memory_file(self, unzip_dirname, cmp_xml, printer, verbose):
        """
        Augments the permissible XILINX FPGA family using a temporary file

        Args:
             unzip_dirname:  The directory containing the unzipped files
             cmp_xml      :  The component.xml file to augment
             printer      :  Prints any output
             verbose      :  The verbose output

        This method reads the original file line-by-line, augmenting the
        relevant lines and writes them to a temporary file which then gets
        moved to replace the original component.xml file.

        The advantage of this method is low memory usage, but at the expense
        of managing the temporary file.
        """

        # -----------------------------------------------------------------
        # Open both the original xml file and the temporary file to receive
        # -----------------------------------------------------------------
        with open(cmp_xml, 'r') as infile, \
            tempfile.NamedTemporaryFile(mode='w',
                                        delete=False,
                                        dir=unzip_dirname) as outfile:

            # -------------------------
            # Add the new FPGA families
            # -------------------------
            for line in infile:
                if 'xilinx:family' in line:
                    outfile.write(self.xil_family)
                else:
                    outfile.write(line)

        # --------------------------------------------------------
        # Replace the original component.xml with the modified one
        # --------------------------------------------------------
        shutil.move(outfile.name, cmp_xml)

        # --------------------------------------------------------
        # Rezip the previously unzipped file, only this time with
        # the augmented FPGA families.
        # --------------------------------------------------------
        status = self.rezip(self.prj_ip_zip,
                            unzip_dirname,
                            printer,
                            verbose)
        return status
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def rezip(zipped_file, dirname, printer, verbose):
        """
        Recursively zip the contents of the previously unzipped directory

        Args:
             zipped_file:  The name of output zipped file
                 dirname:  The directory to zip
                 printer:  Class to print any output
                 verbose:  The verbose output
        """
        # -----------------------------------------------------------------------
        # Remove any stale output zip first: `zip -r` updates an existing archive
        # in place and would leave old entries behind (build.py hit a "Zip file
        # structure invalid" error on rebuild for exactly this reason).
        # -----------------------------------------------------------------------
        if os.path.exists (zipped_file):
            os.remove (zipped_file)

        zip_cmd = ['zip', '-r', zipped_file, '.']
        with subprocess.Popen(zip_cmd,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT,
                              cwd=dirname,
                              text=True,
                              bufsize=1) as process:

            if verbose:
                for line in process.stdout:
                    print(line, end='')

            process.wait()

        return process.returncode
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
