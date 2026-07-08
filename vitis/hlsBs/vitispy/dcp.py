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
  Renames the generically named .dcp files to something unique

'''
# ------------------------------------------------------------------------------

import argparse
import subprocess
import os
import sys
from pathlib import Path
from string  import Template

dir = os.path.split (__file__)[0] + '../'
sys.path.append (dir)
from .version       import Version
from .directory     import Directory
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Dcp :
    """
    Renames the generically named .dcp files to something unique
    """

    # --------------------------------------------------------------------------
    @staticmethod
    def get_file (file, def_dir, def_nam, def_ext) :

        if file :
            dir, namext = os.path.split (file)
            nam, ext    = os.path.splitext (namext)

            if not dir : dir = def_dir
            if not nam : nam = def_nam
            if not ext : ext = def_ext

        else :
            dir = def_dir
            nam = def_nam
            ext = def_ext

        file = os.path.expandvars (os.path.join (dir, nam) + ext)
        file = file.format (vitis_version = Version.version,
                            cmp_name      = def_nam)

        # -------------------------------------------------------------
        # If have a relative path, tack on the def_dir to make absolute
        # -------------------------------------------------------------
        if not os.path.isabs (file) :
            file = os.path.expandvars (os.path.join (def_dir, file))

        return file
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def __init__ (self,
                  dir,
                  dcp_rename,
                  dcp_file,
                  cmp_dir,
                  cmp_name,
                  dgn_dir,
                  jou_file,
                  log_file) :
        """
        The DCP creator's constructor

        Args:
             dir:              The output directory
             dcp_rename        The new name
             dcp_file          The output dcp file's name
             cmp_dir:          The component directory
             cmp_name:         The component name
             dgn_dir           Directory for the journal and log files
             jou_file:         Journal file name
             log_file:         Log file name

        """
        # ----------------------------------------------------
        # Expand any envionment variables in the file name and
        # the new dcp name
        # ----------------------------------------------------
        dir            = os.path.expandvars (dir)
        dir            = dir.format  (vitis_version = Version.version,
                                      cmp_name      = cmp_name)
        self.dcp_dir   = Template(dir).substitute (os.environ)
        self.dcp_dir   = dir

        # ---------------------------------------------------------------
        # The dgn_dir is used to isolate the .jou and .log files
        # way from the .dcp file, basically to get the cruft out of sight
        #
        # The dgn_dir may either be
        #    1) absolute and used as asis
        #    2) relative and used as a subdirectory of the dcp_dir
        #
        # It defaults to 'dgn/'
        # ---------------------------------------------------------------
        if not dgn_dir :
            dgn_dir = os.path.join (self.dcp_dir, 'dgn/')
        else:
            dgn_dir = os.path.expandvars (dgn_dir)
            dgn_dir = dgn_dir.format (vitis_version = Version.version,
                                      cmp_name      = cmp_name)

            # --------------------------------------------------------
            # If dgn_dir is not absolute, make it a sub-dir of dcp_dir
            # --------------------------------------------------------
            if not os.path.isabs (dgn_dir) :
                dgn_dir = os.path.join (self.dcp_dir, dgn_dir)

        dgn_dir = os.path.realpath (dgn_dir)
        if not os.path.isdir (dgn_dir) :
            Path(dgn_dir).mkdir(parents=True, exist_ok=True)


            # --------------------------------------------------------------
        # Convention to make dcp and ip cores compatiable is to add '_0'
        # --------------------------------------------------------------
        dcp_rename      = dcp_rename.format (cmp_name = cmp_name)
        self.dcp_rename = dcp_rename + '_0'

        # ---------------------------------------------------
        # Use the dcp_rename as the file name if not provided
        # ----------------------------------------------------
        if not dcp_file :
            dcp_file = dcp_rename
        else :
            dcp_file = dcp_file.format (cmp_name   = cmp_name,
                                        dcp_rename = dcp_rename)

        self.dcp_file = self.get_file (dcp_file,
                                       self.dcp_dir,
                                       None,
                                       '.dcp')

        # --------------------------------------------------------------------
        # Get the dcp file's name as the journal and log file;s name if needed
        # --------------------------------------------------------------------
        dcp_name = os.path.splitext (os.path.split (self.dcp_file)[1])[0]
        if not jou_file :
            jou_file = dcp_name
        else :
            jou_file = jou_file.format (cmp_name   = cmp_name,
                                        dcp_name   = dcp_name,
                                        dcp_rename = dcp_rename)
        self.jou_file = self.get_file (jou_file, dgn_dir,      None, '.jou')

        if not log_file :
            log_file = dcp_name
        else :
            log_file = log_file.format (cmp_name   = cmp_name,
                                        dcp_name   = dcp_name,
                                        dcp_rename = dcp_rename)
        self.log_file = self.get_file (log_file, dgn_dir,      None, '.log')


        # ---------------------------------------------------------------
        # Construct the directory tree of where to look for the .dcp file
        # ---------------------------------------------------------------
        self.hls_dir  = os.path.join (cmp_dir, 'hls', 'impl')
        self.tcl_file = os.path.join (Directory.tcl, 'dcp_rename_ref.tcl')


        # ------------------------------------------------------
        # Check if both the hls directory and hls dcp file exist
        # ------------------------------------------------------
        self.hls_name   = 'bd_0_hls_inst_0.dcp'
        self.hls_file   = None
        self.hls_exists = os.path.isdir (self.hls_dir)
        if self.hls_exists :
            for path in Path(self.hls_dir).rglob(self.hls_name) :
                self.hls_file = path
                break;
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    def print (self, printer, verbose) :
        printer.itemPlain ("DCP.rename", self.dcp_rename)
        printer.itemPlain ("   .hlsDir", self.hls_dir)
        hls_file = "<hlsDir>/" + (os.path.relpath (self.hls_file, self.hls_dir)
                    if self.hls_file else 'Not found')
        printer.itemPlain ("   .hlsFile", hls_file)
        printer.itemPlain ("   .file",   self.dcp_file)

        if verbose :
            printer.itemPlain ("     .jou", self.jou_file)
            printer.itemPlain ("     .log", self.log_file)

        if not self.hls_exists :
            print ("\n"
                   "ERROR: The hls directory was not found:\n"
                  f"  ->   {self.hls_dir}\n"
                   "  Perhaps --implementation has not been run")

        elif not self.hls_file :

            print ("\n"
              "ERROR: The .dcp file was not found in the hls directory tree\n"
             f"  ->   {self.hls_dir}\n"
             f"       {self.hls_name}\n"
              "  Either it was deleted or -implementation did not correctly run")
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def execute (self, printer, verbose) :

        level = '-verbose' if verbose else '-quiet'
        cmd = ['vivado',
               '-mode',   'batch',
               '-source', self.tcl_file,
              ]

        if self.jou_file : cmd += ['-journal', self.jou_file]
        if self.log_file : cmd += ['-log'    , self.log_file]

        cmd += ['-tclargs',
                self.hls_dir,
                self.dcp_rename,
                self.dcp_file,
                level]


        with subprocess.Popen (cmd,
                               stdout  = subprocess.PIPE,
                               stderr  = subprocess.PIPE,
                               text    = True,
                               bufsize = 1) as process :
            if  verbose :
                for line in process.stdout :
                    if line[0] == '#' : continue
                    print (line, end = '')

            status = process.wait ()
            if True or status :
                for line in process.stderr :
                    print (line, end = '')

        return status
    # --------------------------------------------------------------------------
