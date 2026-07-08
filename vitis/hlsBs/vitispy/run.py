# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import sys
import os
import subprocess
import argparse
import array
from   dataclasses   import dataclass

from   .version       import Version
from   .directory     import Directory
from   .componentInfo import ComponentInfo
from   .dry_run       import DryRun
from   .ip            import Ip
from   .dcp           import Dcp

class Run :
    # --------------------------------------------------------------------------
    @dataclass
    class Msk :
        '''
        Description:
        Defines the permitted combinations of clean, make, and run for
        both the fast and slow implementation of csim and cosim by using
        an array to map the requested actions to a valid one.

        Clean & Run is clearly non-sensical and is remapped to Clean,Make & Run.
        For the slow version of csim (i.e. the implementation using the Vitis
        commands), the following combinations are not supported and remapped
                Clean -> Clean & Make
                Run   -> Make  & Run
        '''

        # ------------------------------------------------
        # The action is a bit map of the following actions
        # ------------------------------------------------
        Clean        : int = 1
        Make         : int = 2
        Run          : int = 4


        # ------------------------------------------
        # Vitis HLS does not permit
        #   1. A bare clean, insists on clean & make
        #   2. A bare run,   insists on make  & run
        # ------------------------------------------
        CSimSlowValid = array.array ('i',
                                     [0,
                                      Clean | Make,        # clean
                                      Make,                # make
                                      Clean | Make,        # clean, make
                                      Make         | Run,  # run
                                      Clean | Make | Run,  # clean, run
                                      Make         | Run,  # make,  run
                                      Clean | Make | Run]) # clean, make, run

        # -------------------------------------------------
        # Only non-sensical Clean | Run -> Clean, Make, Run
        # -------------------------------------------------
        CSimFastValid = array.array ('i',
                                     [0,
                                      Clean,               # clean
                                      Make,                # make
                                      Clean | Make,        # clean, make
                                      Run,                 # run
                                      Clean | Make | Run,  # clean, run
                                      Make         | Run,  # make,  run
                                      Clean | Make | Run]) # clean, make,run

        CoSimValid   = array.array ('i',
                                    [0,
                                     Clean | Make,         # clean
                                     Make,                 # make
                                     Clean | Make,         # clean, make
                                     Make  | Run,          # run
                                     Clean | Make | Run,   # clean, run
                                     Make  | Run,          # make, run
                                     Clean | Make | Run])  # clean, make,run
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class  Stage :
        '''
        Captures the bit map of the stages to run and the options (clean, make,
        and run) for the csim and cosim stages.
        '''
        # ----------------------------------------------------------------------
        CSim           : int = 1
        Synthesis      : int = 2
        CoSim          : int = 4
        Package        : int = 8
        Implementation : int = 16
        Ip_Zip         : int = 32
        Ip_Dcp         : int = 64
        All            : int = 127

        def __init__ (stages, csim, cosim, ip) :
            self.stages = stages
            self.csim   = csim
            self.cosim  = cosim
            self.ip     = ip
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def __init__ (self, options, root, ip,  printer) :
        '''
        Captures the run options which include which stages to run and their
        options, plus output verbosity.

        Args:
           options: The stages and their options
              root: Project's root directory
                ip: The runtime parameters used for the IP stage
           printer: The printer used to display output
        '''
        # ----------------------------------------------------------------------
        self.options  = options
        self.root     = root
        self.ip       = ip
        self.printer  = printer

        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def get_msg (msk, slow) :
        if not slow :
            msg = ['?',
                   'Clean',
                   'Make',
                   'Clean,Make',
                   'Run',
                   'Clean,Make,Run -- Make added, no Run without a Make',
                   'Make,Run',
                   'Clean,Make,Run'][msk] + ' (fast)'

        else :
            msg = ['?',
                   'Clean,Make -- HLS insists on the Make',
                   'Make',
                   'Clean,Make',
                   'Make,Run -- Make added, no Run without a Make',
                   'Clean,Make,Run -- Make added, no Run without a Make',
                   'Make,Run',
                   'Clean,Make,Run'][msk] + ' (slow)'

        return msg;
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def print (self, printer) :

        options        = self.options
        stages         = options.stages

        csim           = stages & Run.Stage.CSim           != 0
        cosim          = stages & Run.Stage.CoSim          != 0
        synthesis      = stages & Run.Stage.Synthesis      != 0
        package        = stages & Run.Stage.Package        != 0
        implementation = stages & Run.Stage.Implementation != 0
        ip_zip         = stages & Run.Stage.Ip_Zip         != 0
        ip_dcp         = stages & Run.Stage.Ip_Dcp         != 0

        if csim :
            csim_msg = self.get_msg (options.csim_msk, options.slow)

        if cosim :
            cosim_msg = self.get_msg (options.cosim_msk, True)

        if self.options.dry_run : printer.line ("Dry Run", True);

        if  csim          :
            printer.line ('Run CSim',                   csim_msg)

        if  synthesis      :
            printer.line ('Run Synthesis',            synthesis)

        if  cosim :
            printer.line ('Run CoSim',                cosim_msg)

        if  package        :
            printer.line ('Run Package',               package)

        if  implementation :
            printer.line ('Run Implementation', implementation)

        if  ip_zip        :
            printer.line ('Run Ip Zip',                 ip_zip)

        if  ip_dcp       :
            printer.line ('Run Ip Dcp',                 ip_dcp)
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def announce (self, sep, caption, verbose = False) :
        if verbose or self.options.verbose :
            if sep     : self.printer.itemPlain ('-' * self.printer.i, '')
            if caption : self.printer.itemPlain (caption, '')
        return True
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def do_fast_cmd (self, cmd, bld_dir, report) :
        # Execute the cmd command
        with subprocess.Popen(cmd,
                              cwd     = bld_dir,
                              stdout  = subprocess.PIPE,
                              stderr  = subprocess.PIPE,
                              text    = True,
                              bufsize = 1) as process :
            for line in process.stdout :
                report (self.printer, self.options.verbose, line)

            for line in process.stderr :
                report (self.printer, True, line)

            # Wait for the process to fully complete and get the return code
            status = process.wait()
            return status
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def do_vitis_cmd (self, cmd, report) :

        # Execute the cmd command
        with subprocess.Popen(cmd,
                              stdout  = subprocess.PIPE,
                              stderr  = subprocess.PIPE,
                              text    = True,
                              bufsize = 1) as process :
            for line in process.stdout :
                report (self.printer, self.options.verbose, line)

            for line in process.stderr :
                report (self.printer, True, line)


            # Wait for the process to fully complete and get the return code
            status = process.wait()
            return status
    # --------------------------------------------------------------------------



    # --------------------------------------------------------------------------
    def do_csim_slow (self, info) :

        slow_msk = self.options.csim_slow_msk

        # -------------------------------------------------------------
        # Either explicitly requested the slow or csim.mk did not exist,
        # so must run the slow version
        # --------------------------------------------------------------
        if    slow_msk == Run.Msk.Clean :
            # Clean only, impossible
            self.announce (False, "ERROR: HLS demands a Make with a Clean:")
            return -1

        elif slow_msk == Run.Msk.Make :
            # Make only
            aux_cfg      = os.path.join (Directory.cfg, "csim_make.cfg")
            self.announce (False, "Building:")

        elif slow_msk == (Run.Msk.Clean | Run.Msk.Make) :
            # Only the clean + make
            aux_cfg      = os.path.join (Directory.cfg, "csim_cleanMake.cfg")
            self.announce (False, "Cleaning & Building")

        elif slow_msk == Run.Msk.Run:
            # Run only, impossible
            self.announce (False, "ERROR: HLS demands a Make with a Run")
            return

        elif slow_msk == (Run.Msk.Clean | Run.Msk.Run):
            # Clean & Run, impossible
            self.announce (False, "ERROR: Cannot Clean & Run without Make")
            return

        elif slow_msk == (Run.Msk.Make  | Run.Msk.Run) :
            aux_cfg      = os.path.join (Directory.cfg, "csim_makeRun.cfg")
            self.announce (False, "Building & Running:")

        elif slow_msk == (Run.Msk.Clean | Run.Msk.Make | Run.Msk.Run) :
            # Clean Make + Run

            aux_cfg      = os.path.join (Directory.cfg, "csim_cleanMakeRun.cfg")
            self.announce (False, "Cleaning, Building & Running")

        else :
            self.announce (False, "Noop")
            return 0

        # ----------------------
        # Create the run command
        # ----------------------
        aux_cfg = os.path.expandvars (aux_cfg)
        run_cmd = ["vitis-run", "--mode", "hls", "--csim",
                   "--config",   info.cfg_files,
                   "--config",   aux_cfg,
                   "--work_dir", info.work_dir]

        # ----------------------------
        # Self the output report style
        # ----------------------------
        if self.options.csim_slow_msk & Run.Msk.Run :
            report_vitis = Run.report_vitis_run
        else                                :
            report_vitis = Run.report_vitis_norun


        with subprocess.Popen(run_cmd,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True,
                              bufsize=1) as process :
            for line in process.stdout :
                report_vitis (self.printer, self.options.verbose, line)

            for line in process.stderr :
                report_vitis (self.printer, True, line)

            # --------------------------------------------------------------
            # Wait for the process to fully complete and get the return code
            # --------------------------------------------------------------
            status = process.wait ()
            return status
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def do_csim_fast (self, bld_dir, info) :

        separator = False

        # -------------------------------------------------------
        if self.options.csim_fast_msk & Run.Msk.Clean :
            clean_cmd  = ['make', '-f', 'csim.mk', 'clean']
            separator  = True
            status     = self.do_fast_cmd (clean_cmd,
                                           bld_dir,
                                           self.report_fastClean)
            if status != 0 : return status
        # -------------------------------------------------------


        # -------------------------------------------------------
        if self.options.csim_fast_msk & Run.Msk.Make :
            if Version.version == "2023.2" :
                os.environ["LIBRARY_PATH"] = "/usr/lib/x86_64-linux-gnu"

            make_cmd   = ['make', '-f', 'csim.mk']
            separator  = self.announce (separator, 'Building:')
            status     = self.do_fast_cmd (make_cmd,
                                           bld_dir,
                                           self.report_fastMake)
            if status != 0 : return status

        # -------------------------------------------------------


        # -------------------------------------------------------
        if self.options.csim_fast_msk & Run.Msk.Run :
            self.announce (separator, 'Running:')
            csim_exe   = info.csim_exe
            csim_argv  = info.csim_argv
            cmd        = csim_exe + ' ' + csim_argv
            status     = os.system (cmd)
            return status
        # -------------------------------------------------------


    # --------------------------------------------------------------------------
    def do_csim (self, info) :

        run_slow  = True
        separator = False

        # -------------------------------
        # If requested, try the fast csim
        # -------------------------------
        if not self.options.slow :

            bld_dir        = os.path.join   (info.work_dir,
                                             'hls',
                                             'csim',
                                             'build')
            csim_mk_exists = os.path.isfile (os.path.join (bld_dir, "csim.mk"))

            # --------------------------------------------------------
            # Demand the make file exists to do the 'fast' option
            # Technically not needed if only doing run, but seems very
            # strange to have the csim.exe and not the csim.mk
            # --------------------------------------------------------
            if csim_mk_exists :
                status = self.do_csim_fast (bld_dir, info)
                return status

        # ------------------------------------------------------------------
        # csim fast not requested or was unable to fulfill because make file
        # did not exist
        # ------------------------------------------------------------------
        self.do_csim_slow (info)

        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def do_cosim (self, info) :

        # ----------------------------------
        # There is no clean option for cosim
        # ----------------------------------
        msk = self.options.cosim_msk & ~Run.Msk.Clean


        if msk == Run.Msk.Make :
            # Make only
            aux_cfg      = os.path.join (Directory.cfg, "cosim_make.cfg")
            self.announce (False, "Building:")

        elif msk == Run.Msk.Run:
            # Run only, impossible
            self.announce (False, "ERROR: HLS demands a Make with a Run")
            return -1

        elif msk == (Run.Msk.Make | Run.Msk.Run) :
            # Make & Run
            aux_cfg      = os.path.join (Directory.cfg, "csim_makeRun.cfg")
            self.announce (False, "Building & Running:")

        else :
            self.announce (False, "Noop")
            return 0

        # ----------------------
        # Create the run command
        # ----------------------
        aux_cfg = os.path.expandvars (aux_cfg)
        run_cmd = ["vitis-run", "--mode", "hls", "--cosim",
                   "--config",   info.cfg_files,
                   "--config",   aux_cfg,
                   "--work_dir", info.work_dir]

        # ----------------------------
        # Self the output report style
        # ----------------------------
        if self.options.cosim_msk & Run.Msk.Run :
            report_vitis = Run.report_vitis_run
        else                                    :
            report_vitis = Run.report_vitis_norun


        with subprocess.Popen(run_cmd,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True,
                              bufsize=1) as process :
            for line in process.stdout :
                report_vitis (self.printer, self.options.verbose, line)

            for line in process.stderr :
                report_vitis (self.printer, True, line)


            # Wait for the process to fully complete and get the return code
            status = process.wait ()
            return status
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def execute (self, cmp_path) :

        info      = ComponentInfo (cmp_path, True)
        if info.errs :
            if info.errs == ComponentInfo.ErrNoCfgFile :
                self.announce (True, None)
                self.printer.itemPlain ('Warning',
                                        'No configuration file found, consider removing this components', '?')

                return

        config    = "--config "    + info.cfg_files
        work_dir  = "--work_dir "  + info.work_dir
        status    = 0
        dry_run   = self.options.dry_run


        if  (self.options.dry_run and
             not self.options.stages & (Run.Stage.Ip_Zip | Run.Stage.Ip_Dcp)) :
            status = 0
            return status;

        # ----------------------------------------------------------------------
        # CSIM
        # -----
        if not dry_run and self.options.stages & Run.Stage.CSim :
            status = self.do_csim (info)
            if status != 0 : return status
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # SYNTHESIS
        # ---------
        if not dry_run and self.options.stages & Run.Stage.Synthesis:
            syn_cmd = ['v++',
                       '--compile',
                       '--mode',     'hls',
                       '--config',   info.cfg_files,
                       '--work_dir', info.work_dir]

            status  = self.do_vitis_cmd (syn_cmd, self.report_vitis_syn)
            if status != 0 : return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # COSIM
        # -----
        if not dry_run and self.options.stages & Run.Stage.CoSim :
            status = self.do_cosim (info)
            if status != 0 : return status
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # PACKAGE
        # -------
        if not dry_run and self.options.stages & Run.Stage.Package  :
            package_cmd = ['vitis-run',
                           '--package',
                           '--mode',    'hls',
                           '--config',   info.cfg_files,
                           '--work_dir', info.work_dir]

            status      = self.do_vitis_cmd (package_cmd, self.report_vitis_run)
            if status != 0 : return status
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # IMPLEMENTATION
        # --------------
        if  not dry_run and self.options.stages & Run.Stage.Implementation :
            impl_cmd = ['vitis-run',
                        '--impl',
                        '--mode',    'hls',
                        '--config',   info.cfg_files,
                        '--work_dir', info.work_dir]

            status   = self.do_vitis_cmd (impl_cmd, self.report_vitis_run)
            if status != 0 : return status
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # IP
        # --
        if  self.options.stages & Run.Stage.Ip_Zip :
            if not self.ip.dir :
                self.printer.itemPlain (
                    'ERROR',
                    'IP Zip generation did not specify an output directory',
                    '*')
                return -1

            self.announce (True, "IP FPGA family augmentation",
                           self.options.verbose)
            ip = Ip (self.ip.dir,
                     self.ip.zip_file,
                     self.ip.family,
                     cmp_path,
                     info)

            ip.print (self.printer, True)
            if not self.options.dry_run :
                status = ip.execute (self.printer,
                                     self.options.verbose)
            else  :
                status = 0

            if status != 0 : return status
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # DCP Rename
        # ----------
        if (self.options.stages & Run.Stage.Ip_Dcp) \
               and info.syn_dcp :
            if not self.ip.dir :
                self.printer.itemPlain (
                    'ERROR',
                    'IP DCP renaming did not specify an output directory', '*')
                return -1

            self.announce (True, "DCP file rename", self.options.verbose)
            dcp = Dcp (self.ip.dir,
                       self.ip.dcp_rename,
                       self.ip.dcp_file,
                       os.path.join (cmp_path, info.cmp_name),
                       info.cmp_name,
                       self.ip.dgn_dir,
                       self.ip.jou_file,
                       self.ip.log_file)

            dcp.print (self.printer, True)

            if not self.options.dry_run and dcp.hls_file:
                status = dcp.execute (self.printer, self.options.verbose)
            else :
                status = 0
        # ----------------------------------------------------------------------

        return status
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def report_vitis_norun (printer, verbose, line) :

        if verbose :
            print (line, end = '')
            return

        suppress = True

        if "ERROR"      in line[0: 5] : suppress = False
        if "WARNING"    in line[0: 7] : suppress = False
        if "make"       in line[0: 4] : suppress = False
        if "Compiling"  in line[0: 9] : suppress = False
        if "Generating" in line[0:10] : suppress = False

        if suppress :
            line = line.rstrip ()
            print (line)
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def report_vitis_run (printer, verbose, line) :

        if  verbose :
            print (line, end='', flush = True)
            return

        suppress = False
        if "INFO"       in line[0:4]   :  suppress = True
        if "**"         in line[0:6]   :  suppress = True
        if "Resolution" in line[0:10]  :  suppress = True
        if line.isspace()              :  suppress = True

        if not suppress :
            line = line.rstrip ()
            print (line, flush = True)
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def report_vitis_syn (printer, verbose, line) :

        if  verbose :
            print (line, end='', flush = True)
            return

        suppress = False
        if   "INFO"                     in line[0: 4] : suppress = True
        elif "WARNING: [RTGEN 206-101]" in line[0:24] : suppress = True
        elif "WARNING: [SYN 201-103]"   in line[0:22] : suppress = True
        elif "**"                       in line[0: 6] : suppress = True
        elif "Resolution"               in line[0:10] : suppress = True
        elif line.isspace()                           :  suppress = True

        if not suppress :
            line = line.rstrip ()
            print (line, flush = True)
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def report_fastClean (printer, verbose, line) :

        if verbose :
            lines = line.split ()
            for line in lines :
                line = line.strip ()
                if '[]'    == line[0:2] : continue
                if 'Done!' == line[0:5] : continue
                if '..'    == line[0:2] : continue
                printer.itemPlain (line.strip (), "")

        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def report_fastMake (printer, verbose, line) :

        if verbose :
            line = line.strip ();
            if len (line) : printer.itemPlain (line, "")


        return
    # --------------------------------------------------------------------------

    csim:       bool
    synthesis:  bool
    cosim:      bool
    package:    bool
    ip:         bool

# ------------------------------------------------------------------------------
