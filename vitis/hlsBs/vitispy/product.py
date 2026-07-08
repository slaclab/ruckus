# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import os
from .version     import Version

class Product :

    from .fpga        import Fpga
    from .dictionary  import Dictionary
    from .dictionary  import Dictionary_of_Builds as Builds
    from .dictionary  import Dictionary_of_Files  as Files
    from .dictionary  import Dictionary_of_Fpgas  as Fpgas
    from .dictionary  import Dictionary_of_Values as Values


    # --------------------------------------------------------------------------
    class Vivado :
        def __init__ (self, flow, syn_dcp) :
            self.flow    = flow
            self.syn_dcp = syn_dcp
            return
        # ----------------------------------------------------------------------

        @staticmethod
        def add_arguments (parser) :
            parser.add_argument ('--flow', help = 'Define vivado = flow')
            parser.add_argument ('--dcp',  help = 'Generate DCP')
            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # Print the Vivado specification
        # ----------------------------------------------------------------------
        def print (self, printer) :  # Vivado
            print ()
            printer.line ('Vivado.flow'   , self.flow)
            printer.line ('      .syn_dcp', self.syn_dcp)
            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        def add (self, cfg_file) :

            # -----------------------------
            # Deprecated starting at 2026.1
            # -----------------------------
            cfg_file.set_value (section = 'hls',
                                key     = 'vivado.flow',
                                value   = self.flow)

            cfg_file.set_value (section = 'hls',
                                key     = 'vivado.syn_dcp',
                                value   = self.syn_dcp)
            return
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # End: Product.Vivado
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    # Holds the HLS configuration Package specification
    # --------------------------------------------------------------------------
    class Package :

        # ----------------------------------------------------------------------
        # Capture the package specification
        # ----------------------------------------------------------------------
        class Ip :
            # ------------------------------------------------------------------
            # Construct the package IP
            # ------------------------------------------------------------------
            def __init__ (self, name, vendor, library, version) :  # Package.Ip
                self.name_template    = name
                self.vendor           = vendor
                self.library          = library
                self.version          = version
                self.name             = None
                return
            # ------------------------------------------------------------------


            # -------------------------------`----------------------------------
            # Add the Package IP command line arguments to the parser
            # ------------------------------------------------------------------
            @staticmethod
            def add_arguments (parser) :   # Package.Ip
                parser.add_argument ('--ip_package', help='Package Name', action='append', dest = 'package')
                parser.add_argument ('--ip_vendor',  help='Package Vendor'               , dest = 'vendor')
                parser.add_argument ('--ip_library', help='Library'                      , dest = 'library')
                parser.add_argument ('--ip_version', help='Version Number'               , dest = 'version')

                return
            # ------------------------------------------------------------------


            # ------------------------------------------------------------------
            # Print the package IP specification
            # ------------------------------------------------------------------
            def print (self, printer) :     # Package.Ip

                # This is printed with configuration/component
                #if self.name : print (f"\n{'Name'          :{n}s}: {self.name}")

                print ()
                printer.line ('Ip    .Vendor',  self.vendor)
                printer.line ('      .Library', self.library)
                printer.line ('      .Version', self.version)
                return
            # ------------------------------------------------------------------

            name_template: str
            name         : str
            vendor       : str
            library      : str
            version      : str
        # ----------------------------------------------------------------------
        # END: Product.Package.Ip
        # ---------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # Manages the package Output specification
        # ----------------------------------------------------------------------
        class Output :

            # ------------------------------------------------------------------
            # Construct the output specification
            # ------------------------------------------------------------------
            def __init__ (self, format, syn) :   # Package.Output
                self.format = format
                self.syn    = syn
                return
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Add the package output command line parameters to the parser
            # ------------------------------------------------------------------
            @staticmethod
            def add_arguments (parser) :        # Package.Output
                return
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Print the package output specification
            # ------------------------------------------------------------------
            def print (self, printer) :         # Package.Output

                print ()
                printer.line ('Output.format', self.format)
                printer.line ('      .syn',    'True' if self.syn else 'False')
                return
            # ------------------------------------------------------------------


            # ------------------------------------------------------------------
            # Add the package command line parameters to the parser
            # ------------------------------------------------------------------
            @staticmethod
            def add_arguments (parser) :       # Package.Output
                parser.add_argument ('--format', help = 'Output format')
                parser.add_argument ('--syn',    action = 'store_true', help='Synthesis Output')
                return
            # ------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # END: Product.Output
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # Add package to configuration
        # ----------------------------------------------------------------------
        def add (self, cfg_file) :         # Package

            # -----------------------------
            # Deprecated starting at 2026.1
            # -----------------------------
            if Version.version < '2026.1' :
                cfg_file.set_value (section = 'hls',
                                    key     = 'flow_target',
                                    value   = 'vivado')

            cfg_file.set_value (section = 'hls',
                                key     = 'package.ip.name',
                                value   = self.ip.name)

            cfg_file.set_value (section = 'hls',
                                key     = 'package.ip.vendor',
                                value   = self.ip.vendor)
            cfg_file.set_value (section = 'hls',
                                key     = 'package.ip.library',
                                value   = self.ip.library)

            cfg_file.set_value (section = 'hls',
                                key     = 'package.ip.version',
                                value   = self.ip.version)

            cfg_file.set_value (section = 'hls',
                                key     = 'package.output.format',
                                value   = self.output.format)

            cfg_file.set_value (section = 'hls',
                                key     = 'package.output.syn',
                                value   = self.output.syn)

            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        @staticmethod
        def add_arguments (parser) :           # Package
            Product.Package.Ip.    add_arguments (parser)
            Product.Package.Output.add_arguments (parser)
            return
        # ----------------------------------------------------------------------


        # ---------------------------------------------------------------------
        def print (self, printer) :                  # Package
            self.ip    .print (printer)
            self.output.print (printer)
            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        def __init__ (self, ip, output) :     # Package
            self.ip     = ip
            self.output = output
            return

        ip     : Ip
        output : Output
        # ------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # END: Product.Package
    # --------------------------------------------------------------------------


    # ----------------------------------------------------------------------
    class Targets :
        def __init__ (self, *dictionaries) :
            self.dictionaries   = dictionaries
            return
    # ----------------------------------------------------------------------
    # END: Product.Targets
    # ----------------------------------------------------------------------


    # ----------------------------------------------------------------------
    def __init__ (self, project, targets, package, vivado) :

        self.targets         = targets
        self.project         = project
        self.project.package = package
        self.project.vivado  = vivado

        return
    # ----------------------------------------------------------------------


    # ----------------------------------------------------------------------
    def print (self, printer, quiet) :       # Product
        self.package.print (printer)
        self.vivado. print (printer)
        return

    def add (self, cfg_file) :          # Product
        self.package.add (cfg_file)
        self.vivado.add  (cfg_file)
        return
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# END: Product
# ------------------------------------------------------------------------------
