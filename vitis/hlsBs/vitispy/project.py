# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import os,sys
from types    import SimpleNamespace
from datetime import datetime

from dataclasses import dataclass
from .workspace import Workspace
from .importfile import ImportFile
from .version import Version
from .files import add_version
from .git import Git



# ------------------------------------------------------------------------------
# The project definition
# ------------------------------------------------------------------------------
class Project:

    from .product import Product
    from .git     import Git

    # --------------------------------------------------------------------------
    # Project Ip parameterization
    # --------------------------------------------------------------------------
    class Ip:
        # ----------------------------------------------------------------------
        def __init__(self,
                     family=None,
                     dcp_rename=None,

                     # Output file specifications
                     dir=None,

                     # IP/Zip FPGA augmentation
                     zip_file=None,

                     # DCP rename
                     dcp_file=None,
                     dgn_dir=None,
                     jou_file=None,
                     log_file=None):



            self.family = family
            self.dcp_rename = dcp_rename if dcp_rename else '{cmp.name}'

            self.dir = dir
            self.zip_file = zip_file

            self.dcp_file = dcp_file
            self.dgn_dir = dgn_dir
            self.jou_file = jou_file if jou_file else '{dcp.name}'
            self.log_file = log_file if log_file else '{dcp.name}'
            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------

        def set_dir(self, products_root):

            if not self.dir:
                self.dir = os.path.join(products_root,
                                        'ip',
                                        '{vitis.version}')
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------

        @staticmethod
        def add_arguments(parser):
            parser.add_argument('--ip-dir',
                                help='IP output file',
                                dest='ip_dir')

            parser.add_argument('--ip-zip_file',
                                help='IP zip file name',
                                dest='ip_zip_file')

            parser.add_argument('--ip-family',
                                help='List of FPGA families to allow',
                                dest='ip_family')

            parser.add_argument('--ip-dcp_file',
                                help='IP dcp file name',
                                dest='ip_dcp_file')

            parser.add_argument('--ip-dgn_dir',
                                help='Directory for the .jou, log files',
                                dest='ip_dgn_dir')

            parser.add_argument('--ip-dcp_journal_file',
                                help='IP dcp journal file name',
                                nargs='?',
                                const='__default__',
                                dest='ip_dcp_jou_file',
                                default=None)

            parser.add_argument('--ip-dcp_log_file',
                                help='IP dcp log file name',
                                nargs='?',
                                const='_-default__',
                                dest='ip_dcp_log_file',
                                default=None)

            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------

        def replace(self, args):
            if (hasattr(args, 'ip_dir') and
                    args.ip_dir):
                self.dir = args.ip_dir

            if (hasattr(args, 'ip_zip_file') and
                    args.ip_zip_file):
                self.name = args.ip_zip_file

            if (hasattr(args, 'ip_family') and
                    args.ip_family):
                self.family = args.ip_family

            if (hasattr(args, 'ip_dcp_file') and
                    args.ip_dcp_file):
                self.dcp_file = args.ip_dcp_file

            if (hasattr(args, 'ip_dgn_dir') and
                    args.ip_dgn_dir):
                self.dcp_dgn_dir = args.ip_dgn_dir

            if (hasattr(args, 'ip_dcp_jou_file') and
                    args.ip_dcp_jou_file):
                self.jou_file = args.ip_dcp_jou_file

            if (hasattr(args, 'ip_dcp_log_file') and
                    args.ip_dcp_log_file):
                self.log_file = args.ip_dcp_log_file

            return
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # END: Product.Ip
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class Print:
        def __init__(self, target_label, com_print, cfg_print):
            self.target_label = target_label
            self.com_print = com_print
            self.cfg_print = cfg_print
            return
    # --------------------------------------------------------------------------
    # END Product.Print
    # --------------------------------------------------------------------------

    def include(self, file):
        m = ImportFile(file)
        m.add()
        m.load()
        return m

    # --------------------------------------------------------------------------
    # Include file for processing
    # --------------------------------------------------------------------------
    def import_module(self, file):
        m = ImportFile(file)
        self.modules.append(m)
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def __init__(self,
                 in_needs,
                 project_files,
                 root,
                 products_root,
                 build_root,
                 workspace,
                 cfg_root,
                 ip_root):  # Project

        self.root = root
        self.products_root = products_root
        self.build_root = build_root
        self.workspace = workspace
        self.cfg_root = cfg_root
        self.ip_root = ip_root

        self.error = 0
        self.fpgas = []
        self.package = None
        self.vivado = None
        self.verbose = False
        self.prj_files = []
        self.target_opt = 'targets'
        self.version = Version

        self.configurations = None
        self.spc_print = None
        self.target_label = None
        self.git = None

        needs = in_needs

        if self.root:
            needs &= ~Project.Need.Root
            self.root = os.path.expandvars(self.root)
            self.git = Git (self.root)

        # If need the workspace
        if needs & Project.Need.Workspace:
            if self.workspace:
                needs &= ~Project.Need.Workspace
            elif self.build_root is None:
                needs |= Project.Need.Build_Root

        # If need cfg root
        if needs & Project.Need.Cfg_Root:
            if self.cfg_root:
                needs &= ~Project.Need.Cfg_Root
            if self.build_root is None:
                needs |= Project.Need.Build_Root

        # If need ip root
        if needs & Project.Need.Ip_Root:
            if self.ip_root:
                needs &= ~Project.Need.Ip_Root
            if self.products_root is None:
                needs |= Project.Need.Products_Root

        if needs & Project.Need.Build_Root:
            if self.build_root:
                needs &= ~Project.Need.Build_Root
            elif self.products_root is None:
                needs |= Project.Need.Products_Root

        # If need the products root is
        if needs & Project.Need.Products_Root:
            if self.products_root:
                needs &= ~Project.Need.Products_Root
            elif self.root is None:
                needs |= Project.Need.Root

        self.has_project_file = False

        if project_files and needs:

            files = []
            if isinstance(project_files, list):
                files = project_files
            else:
                files = [project_files]

            self.modules = []
            for file in files:
                abs_file = os.path.abspath(file)
                if abs_file != file:
                    print(
                        "\n"
                        f"{'*'*78}\n"
                        f"WARNING* The project file <{file}>\n"
                        "       * is specified as a relative path.\n"
                        "       * This is discouraged.\n"
                        "       * It makes the command directory dependent leading to mysterious behavior.\n"
                        f"{'*'*78}\n")
                self.prj_files.append(abs_file)
                self.import_module(abs_file)

                for module in self.modules:
                    module.add()

                for module in self.modules:
                    module.load()

            # --------------------------------
            # Get the bare minimum information
            # ------------------------------------
            module = self.modules[0].module
            self.has_project_file = True

            # Project Root
            if needs & Project.Need.Root:
                if hasattr(module, 'get_project_root'):
                    self.root = module.get_project_root(self)

                # If have got a root, expand it
                if self.root:
                    self.root = os.path.expandvars(self.root)

                # Else default to the root directory of the project files
                else:
                    self.root = os.path.split(
                        os.path.split(self.prj_files[0])[0])[0]

            # Make the git information available
            if not self.git:
                self.git = Git (self.root)

            # Project Products
            if needs & Project.Need.Products_Root:
                if hasattr(module, 'get_products_root'):
                    self.products_root = module.get_products_root(self)
                    if self.products_root:
                        self.products_root = os.path.expandvars(
                            self.products_root)

                if self.products_root is None:
                    self.products_root = os.path.join(self.root, 'products')

                needs &= ~Project.Need.Products_Root

            # Project Build
            if needs & Project.Need.Build_Root:
                if hasattr(module, 'get_build_root'):
                    self.build_root = module.get_build_root(self)
                    if self.build_root:
                        self.build_root = os.path.expandvars(self.build_root)

                if self.build_root is None:
                    self.build_root = os.path.join(self.products_root, 'build')

                needs &= ~Project.Need.Build_Root

            # Project Cfg_Root
            if needs & Project.Need.Cfg_Root:
                if hasattr(module, 'get_cfg_root'):
                    self.cfg_root = module.get_cfg_root(self)
                    if self.cfg_root:
                        self.cfg_root = os.path.expandvars(self.cfg_root)

            # Project Workspace
            if needs & Project.Need.Workspace:
                if hasattr(module, 'get_workspace'):
                    self.workspace = module.get_workspace(self)
                if self.workspace:
                    self.workspace = os.path.expandvars(self.workspace)

            # Project Ip_Root
            if needs & Project.Need.Ip_Root:
                if hasattr(module, 'get_ip_root'):
                    self.cfg_root = module.get_ip_root(self)
                if self.ip_root:
                    self.ip_root = os.path.expandvars(self.ip_root)

        # ----------------------------------------------------------------------

        if needs & Project.Need.Products_Root:
            if self.products_root is None:
                if self.root is None:
                    self.error = Project.Need.Products_Root
                    return

                self.products_root = os.path.join(self.root, 'products')

            self.products_root = os.path.expandvars(self.products_root)

        if needs & Project.Need.Build_Root:
            if self.build_root is None:
                if self.products_root is None:
                    self.error = Project.Need.Build_Root
                    return
                self.build_root = os.path.join(self.products_root, 'build')

        if needs & Project.Need.Workspace:
            if self.workspace is None:
                if self.build_root is None:
                    self.error = Project.Need.Build_Root
                    return

                self.workspace = os.path.join(self.build_root,
                                              'ws',
                                              '{vitis.version}')

        if needs & Project.Need.Cfg_Root:
            if self.cfg_root is None:
                if self.build_root is None:
                    self.error = Project.Need.Cfg_Root
                    return

                self.cfg_root = os.path.join(self.build_root,
                                             'cfg',
                                             '{vitis.version}')

        if needs & Project.Need.Ip_Root:
            if self.ip_root is None:
                if self.build_root is None:
                    self.error = Project.Need.Ip_Root
                    return

                self.ip_root = os.path.join(self.build_root,
                                            'ip',
                                            '{vitis.version}')

        # ---------------------------------------------------
        # Add any unresolved vitis version or git information
        # Convert all to absolute paths
        # ---------------------------------------------------
        self.global_map = { 'vitis' : SimpleNamespace (version = Version.version),
                            'git'   : self.git.ns }
        self.products_root = self.resolve (self.products_root)
        self.build_root = self.resolve (self.build_root)
        self.workspace = self.resolve (self.workspace)
        self.cfg_root = self.resolve (self.cfg_root)
        self.ip_root = self.resolve (self.ip_root)
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def resolve (self, file) :
        if file:
            file = os.path.expandvars (file)
            file = file.format_map (self.global_map)
            file = os.path.abspath (file)

        return file
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def report(self, needs):
        if needs & Project.Need.Workspace:
            print(
                "\nERROR: Could not determine workspace directory, one of\n"
                "       --root, --products_root, --workspace must be specified",
                file = sys.stderr)
            return self.error

        elif needs & Project.Need.Products_Root:
            print(
                "\nERROR: Could not determine products directory, one of\n"
                "       --root, --products_root must be specified",
                file = sys.stderr)
            return self.error

        elif needs & Project.Need.Root:
            print(
                "\nERROR: Could not determine project root directory, one of\n"
                "         --root must be specified",
                file = sys.stderr)
            return self.error

        return 0
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def get_products(self):

        if not self.git:
            self.git = Git(os.path.expandvars(self.root))

        products = self.modules[0].module.get_products(self)

        if not isinstance(products, list):
            products = [products]

        self.products = products


        return products
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def get_ip(self):

        if hasattr(self.modules[0].module, 'get_ip'):
            self.ip = self.modules[0].module.get_ip
        else:
            self.ip = None

        return self.ip
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def get_dcp(self):
        self.dcp = self.modules[0].module.get_dcp(self)
        return self.dcp
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def replace(self, args):

        # Check if args override project settings
        if (hasattr(args, 'verbose') and
                (args.verbose is not None)):
            self.verbose = args.verbose

        if (hasattr(args, 'configurations') and
                (args.configurations is not None)):
            self.configurations = args.configurations

        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def add_arguments(parser, add_cfg=False):      # Project

        parser.add_argument('--project',
                            help='Project definition file')

        parser.add_argument('--root',
                            help='Project root directory')

        parser.add_argument('--products-root',
                            dest='products_root',
                            help='Products root directory')

        return

    def print_prj_files(self, printer, pad, verbose):

        field = '.File'

        if verbose and len(self.prj_files) > 1:
            field += 's'
        printer.prefixed_line('', field, self.prj_files[0])

        if verbose:
            for f in self.prj_files[1:]:
                printer.line('', f)
        return

    def add(self, cfg_file):        # Project
        self.package.add(cfg_file)
        self.vivado.add(cfg_file)
        return

    products: Product = None
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def print_project(self, printer, verbose):

        printer.line("Vitis Version", Version.version)

        formatted_time = datetime.now().strftime("%Y%m%d%H%M%S")
        printer.line("Build time", formatted_time)

        pad = len("Project")
        if self.root:
            printer.line("Project.Root", self.root)

        self.print_prj_files(printer, pad, verbose)

        if not verbose:
            return

        if self.git.repo:
            print()
            self.git.print(printer, pad, verbose)

        if self.package:
            self.package.print(printer)
        if self.vivado:
            self.vivado .print(printer)

        return
# ------------------------------------------------------------------------------

    @dataclass
    class Need:
        Root: int = 1             # root
        Products_Root: int = 2    # root/products
        Ip_Root: int = 4          # root/products/ip
        Build_Root: int = 8       # root/products/build
        Workspace: int = 16       # root/products/build/ws
        Cfg_Root: int = 32        # root/products/build/cfg
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
