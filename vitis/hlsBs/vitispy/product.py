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
import sys
import inspect
from .version import Version


class Product:

    from .fpga import Fpga

    # ------------------------------------------------------------------------------
    class _Ctb:
        '''
        Internal class following the pattern of a normal python dictionary except
        the value is a 2 element list consisting of 'type' and a 'value'. The value(s)
        will be compiled into one or more 2 element lists, where the first element
        is a type and the second a single value or a list of values of 'type'
        e.g. 'Files', 'Fpgas', etc

        Example:
           kvs       = 'fpga', ['Fpgas', fpga0, fpga1]
           Produces [  'fpga', [fpga0, fpga ]]

          kvs  = 'network', ['Files', '$NETWORKS/*.hh']
          Produces [ [Produces a dictionary for each matching wildcarded file
          e.g.     [ 'network' : [$NETWORKS/a.hh, $NETWORKS/b.hh,..] ]
        '''
        # --------------------------------------------------------------------------
        def __init__(self, key, tvs):
            '''
            Constructs a class consisting of a 2 element list

            Args:
               key:   A string which will eventually become the dictionary's key
               tvs:   A 2 element list consisting of a type and one or a list of values
            '''
            self.key = key
            self.tvs = tvs
            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        def __str__(self):
            return "key = {}\n, tvs = {}".format(self.key, self.tvs)
        # -----------------------------------------------------------------------

    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class CtbBuilds(_Ctb):
        def __init__(self, key, builds):
            if not isinstance(builds[0], (list, tuple)):
                builds = (builds,)
            super().__init__(key, ['Builds', builds])
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class CtbFpgas (_Ctb):
        def __init__(self, key, fpgas):
            if not isinstance(fpgas, (list, tuple)):
                fpgas = (fpgas,)
            super().__init__(key, ['Fpgas', fpgas])
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class CtbFiles (_Ctb):
        def __init__(self, key, files):
            if not isinstance(files, (list, tuple)):
                files = (files,)
            super().__init__(key, ['Files', files])
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class CtbValues (_Ctb):
        def __init__(self, key, values):
            if not isinstance(values, (list, tuple)):
                values = (values[0],)
            super().__init__(key, ['Values', values])
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class CfgTemplate:
        def __init__(self, prefix, template):
            self.prefix = prefix if prefix else 'cfg'
            self.template = template
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class CmpTemplate:
        def __init__(self, prefix, template):
            self.prefix = prefix if prefix else 'cmp'
            self.template = template
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def add_root(root, paths):
        add_dir = (lambda d, p:
                   os.path.realpath(p if os.path.isabs(p)
                                    else os.path.join(d, p)))

        lt = (list, tuple)
        if paths:
            tpaths = paths if isinstance(paths, (list, tuple)) else (paths,)
            if root:
                root_exp = os.path.expandvars (root)
                # Add the root directory to non absolute paths
                rpaths = (tuple([add_dir(root_exp, os.path.expandvars(path))
                                 for path in tpaths]))
            else:
                rpaths = (tuple([os.path.expandvars(path)
                                 for path in tpaths]))
        return rpaths
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def check_fp(fps, frame, isfile):

        errs = 0

        for fp in fps:
            exists = os.path.isfile(fp) if isfile else os.path.isdir(fp)
            if exists:
                continue

            if errs == 0:
                linenum = frame.f_lineno
                co_method = frame.f_code.co_name
                co_file = frame.f_code.co_filename
                which = "Source file" if isfile else "Include path"
                print(f"\nERROR: {which} not found, from\n"
                        f"     : {co_file}\n"
                        f"     : {co_method}:{linenum}", file=sys.stderr)

            print(f"     : {fp}", file=sys.stderr)
            errs += 1

        if errs:
            print(file=sys.stderr)
        return errs
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class IncludePaths ():
        '''
        Class to define one or more include file paths

        Args:
           root:  A common directory applied to all paths
           paths: The path(s) to define. May be a single, list or tuple
           type:  One of 'rel_path' (the default) or 'abs_path'

        Returns:
        The definition of the included class
        '''
        # ----------------------------------------------------------------------

        def __init__(self, root, paths, type='rel_path'):

            self.frame = inspect.currentframe().f_back
            self.root = root
            self.paths = Product.add_root(root, paths)
            self.errs = Product.check_fp(self.paths, self.frame, False)
            self.type = type
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class DefineValue ():
        '''
        Class to define adding a -DNAME=value to the compilation

        Args:
           name : The name of the #define
           value: The value of the #define. This may be an explicit value
                  e.g. 10 or a logical symbolic, e.g. '{value}'
        '''
        # ----------------------------------------------------------------------

        def __init__(self, name, value):
            self.name = name
            self.type = 'string'
            self.value = value
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class IncludeFile:
        '''
        Class to define adding a -DNAME=file, i.e. a compile-time define include
        file to the compilation

        Args:
           name     : The name of the #define
           file     : The include file path. This may be an explict value, .e.g.
                     'file.hh' or a logical symbolic, e.g. '{file_path}'
          rel_path : If specified the relative path to use when including
                     the file. If omitted or specified as None, the path
                     will be used as is. Almost invariably this is defined
                     to be the normal include path since the file to be
                     included is often in a subdirectory of that path

        Example:
        Suppose one has a number of include files defining various levels
        of optimizations in a directory call 'opt' under the usual project's
        include directory:

        include/myproject/opt/Opt1.hh
                             /Opt2.hh

        To explicitly include this at compile-time
        def_include = Product.Include ('OPT_FILE',
                                       'opt/Opt1.hh',
                                       '<path_to>/include/myproject')

        More likely one has defined a component contributor
        '''
        # ----------------------------------------------------------------------
        def __init__(self, name, paths, rel_path=None):
            self.name = name
            # if isinstance (paths, (list,tuple)) else (paths,)
            self.value = paths
            self.rel_path = rel_path
            self.type = 'rel_file' if rel_path else 'abs_file'
            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class Sources:
        '''
        Defines a set of files which share a common set of includes and defines

        Args:
          root    :  A root directory path applied to the source files
          files   :  A single, list or tuple of absolute file paths to
                     be compiled
          includes:  A single, list or tuple of IncludePaths
          defines :  A single, list or tuple of defines
          ldflags :  Any special load flags
        '''
        # ----------------------------------------------------------------------
        def __init__(self, root, files, includes, defines, **kwargs):
            # ---------------------------------------------------------------
            # The files, includes, defines can all be single, lists or tuples
            # For a consistent API, an single is converted to a tuple
            # ---------------------------------------------------------------
            self.frame = inspect.currentframe().f_back
            self.root = root
            self.files = Product.add_root(root, files)
            self.errs = Product.check_fp(self.files, self.frame, True)
            self.includes = (includes if isinstance (includes, (list, tuple))
                                                    else (includes,))
            self.inc_errs = 0
            for include in self.includes :
                if not isinstance(include, Product.IncludePaths):
                    self.inc_errs = 1
                    self.errs += 1
                    obj_type = type(includes).__name__
                    linenum = self.frame.f_lineno
                    co_method = self.frame.f_code.co_name
                    co_file = self.frame.f_code.co_filename

                    print(
                        f"\nERROR: In'Project.Sources', 'includes' is a {obj_type}\n"
                           "     :  must be a 'Product.IncludePaths'\n"
                          f"     :  {co_file}\n"
                          f"     :  {co_method}:{linenum}",
                        file=sys.stderr)

            self.defines = defines
            if defines:
                if not isinstance(defines, (list, tuple)):
                    self.defines = (defines,)

            if kwargs:
                if 'ldflags' in kwargs:
                    self.ldflags = kwargs['ldflags']

            return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class Build:
        '''
        Defines a single build product

        Args:
           top:        Name of the top level HLS method
           tb:         A single, list or tuple of testbench Product.sources
           syn:        A single, list or tuple of synthesis/HLs Product.sources
           ldflags:    Load library flags
           csim_argv   A string giving the arguments to be passed to csim
           cosim_argsv A string giving the arguments to be passed to cosim
        '''
        # ----------------------------------------------------------------------

        def __init__(self, top, tb, syn, csim_argv, cosim_argv, ldflags = None):

            self.top = top
            self.tb = tb if isinstance(tb, (list, tuple)) else (tb,)
            self.syn = syn if isinstance(syn, (list, tuple)) else (syn,)
            self.ldflags = ldflags
            self.csim_argv = csim_argv
            self.cosim_argv = cosim_argv

            errs = 0

            # ------------------------------------------------------------------
            # Check that all members of self.tb and self.syn are Product.Sources
            # ------------------------------------------------------------------
            frame = inspect.currentframe().f_back
            tb_errs = self.check_sources(self.tb, frame, True)
            syn_errs = self.check_sources(self.syn, frame, False)
            errs += tb_errs + syn_errs

            # -------------------
            # Abort if any errors
            # -------------------
            if tb_errs == 0:
                for src in self.tb:
                    errs += src.errs
                    if src.inc_errs == 0:
                        errs += src.inc_errs

            if syn_errs == 0:
                for src in self.syn:
                    errs += src.errs
                    if src.inc_errs == 0:
                        errs += src.inc_errs

            if errs:
                print(file=sys.stderr)
                exit(-1)

            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        @staticmethod
        def check_sources(srcs, frame, istb):
            idx = 0
            errs = 0
            for src in srcs:
                if not isinstance(src, Product.Sources):
                    errs += 1
                    obj_type = type(src).__name__
                    linenum = frame.f_lineno
                    co_method = frame.f_code.co_name
                    co_file = frame.f_code.co_filename
                    which = "tb" if istb else "syn"

                    print(
                        f"\nERROR: In 'Project.Build', '{which}[{idx}]'"
                        f" is of type '{obj_type}'.\n"
                           "     : Must be of type 'Product.Sources'\n"
                          f"     : {co_file}\n"
                          f"     :  {co_method}:{linenum}", file=sys.stderr)

            return errs
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class Contributors (list):
        '''
        Defines the various contributors that compose a Component

        Args:
           ctb_builds:  The mandatory build contributors
           ctb_fpgas::  The mandatory fpgas contributors
           *args     :  All other contributors
        '''
        # ----------------------------------------------------------------------
        def __init__ (self, ctb_builds, ctb_fpgas, *args):
            stem  = self.__module__

            errs = 0
            keys = []

            idx : int = 2
            errs = self.check (0, ctb_builds, (Product.CtbBuilds,),               keys, stem, errs)
            errs = self.check (1, ctb_fpgas,  (Product.CtbFpgas,),                keys, stem, errs)
            for ctb in args:
                errs = self.check (idx, ctb, (Product.CtbFiles,Product.CtbValues), keys, stem, errs)


            if errs :
                frame = inspect.currentframe().f_back
                print ( " at\n"
                       f"     : {frame.f_code.co_filename}\n"
                       f"     : {frame.f_code.co_name}:{frame.f_lineno}\n",
                        file = sys.stderr)
                exit (-1)

            self.append (ctb_builds)
            self.append (ctb_fpgas)
            self.extend (args)


            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        @staticmethod
        def check (idx, ctb, allowed, keys, stem, errs):
            cls_name = lambda cls: (type(cls) if not type(cls).__module__ == stem
                                    else '<' + type(cls).__qualname__ + '>')


            # --------------------------------------------------------
            # Check the contributor is one of the allowed contributors
            # --------------------------------------------------------
            ctb_err = not isinstance (ctb, allowed)

            # ------------------------------------
            # Check the contributors key is unique
            # ------------------------------------
            ctb_key = ctb.key
            duplicates = [idy for idy, key_val in keys  if key_val == ctb_key]
            keys.append ([idx, ctb_key])
            key_err = len(duplicates)


            # ----------------------------------------------
            # If have any errors, construct the error string
            # ----------------------------------------------
            if ctb_err or key_err:
                estr = ""

                # ----------------------------
                # If this the first error seen
                # ----------------------------
                if errs == 0:
                    estr += f"\nERROR: In Products.Contributors"

                estr += f"\n     : Contributor #{idx} {cls_name(ctb)}"

                # ---------------------------------------
                # Have passed an illegal contributor type
                # ---------------------------------------
                if ctb_err:
                    estr += f"\n     * Must be of type(s) :  "
                    prefix = ''
                    for cls in allowed :
                        estr += prefix + '<' + cls.__qualname__ + '>'
                        prefix = " or "

                # -----------------------------------
                # All contributor keys must be unique
                # -----------------------------------
                if key_err:
                    estr += f"\n     * Has a duplicate key: '{ctb_key}' from Contributors #{duplicates}"

                print (estr, file = sys.stderr)
                return -1

            return 0
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class Components:
        '''
        Defines the components

        Args:
           contributors: These are Product.Builds, Product.Fpgas,
                         Product.Include
                         together determine the components
           cfg_template: How to name the configuration file path
           cmp_template: How to name the component

        Details:
        The contributors must include at least one instance of the the .Builds
        and .Fpgas. All contributors may appear multiple times provided they
        are uniquely named

        The cfg_template and cmp_template must contain at least one logical
        symbol name from every contributor class that has more than one member.
        This is how the configuration file paths and components are named in
        the directory structure.

        Example:
           cfg_template {build_id}-{fpga_id}
           cmp_template {cfg_name}
        '''
        # ----------------------------------------------------------------------
        def __init__(self, contributors, cfg_template, cmp_template):

            stem = self.__module__
            errs = 0
            errs += self.check (contributors, "contributors", Product.Contributors, stem, errs)
            errs += self.check (cfg_template, "cfg_template", Product.CfgTemplate,  stem, errs)
            errs += self.check (cmp_template, "cmp_template", Product.CmpTemplate,  stem, errs)

            if errs:
                frame = inspect.currentframe().f_back
                print ( " at\n"
                       f"     : {frame.f_code.co_filename}\n"
                       f"     : {frame.f_code.co_name}:{frame.f_lineno}\n",
                       file = sys.stderr)

                sys.exit (-1)

            self.contributors = contributors
            self.cfg_template = cfg_template
            self.cmp_template = cmp_template

            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        @staticmethod
        def check (clsObj, clsName, expected, stem, errs):
            cls_name = lambda cls: (type(cls) if not type(cls).__module__ == stem
                                    else '<' + type(cls).__qualname__ + '>')

            # --------------------------
            # Check the class is allowed
            # --------------------------
            err = not isinstance (clsObj, expected)

            # -----------------------------------------
            # If have error, construct the error string
            # -----------------------------------------
            if err:
                estr = ""

                # ----------------------------
                # If this the first error seen
                # ----------------------------
                if errs == 0:
                    estr += f"\nERROR: In Products.Components (contributors, cfg_template, cmp_template)"
                estr += (f"\n     : Argument '{clsName}' is of type {cls_name(clsObj)}"
                         f"\n     * Must be of type: " + '<' + expected.__qualname__ + '>')

                print (estr, file = sys.stderr)
                return 1

            return 0
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    class Vivado:
        def __init__(self, flow, syn_dcp):
            self.flow = flow
            self.syn_dcp = syn_dcp
            return
        # ----------------------------------------------------------------------

        @staticmethod
        def add_arguments(parser):
            parser.add_argument('--flow', help='Define vivado = flow')
            parser.add_argument('--dcp', help='Generate DCP')
            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # Print the Vivado specification
        # ----------------------------------------------------------------------
        def print(self, printer):  # Vivado
            print()
            printer.line('Vivado.flow', self.flow)
            printer.line('      .syn_dcp', self.syn_dcp)
            return
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------

        def add(self, cfg_file):

            # -----------------------------
            # Deprecated starting at 2026.1
            # -----------------------------
            cfg_file.set_value(section='hls',
                               key='vivado.flow',
                               value=self.flow)

            cfg_file.set_value(section='hls',
                               key='vivado.syn_dcp',
                               value=self.syn_dcp)
            return
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # End: Product.Vivado
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    # Holds the HLS configuration Package specification
    # --------------------------------------------------------------------------
    class Package:

        # ----------------------------------------------------------------------
        # Capture the package specification
        # ----------------------------------------------------------------------
        class Ip:
            # ------------------------------------------------------------------
            # Construct the package IP
            # ------------------------------------------------------------------
            def __init__(self, name, vendor, library, version):  # Package.Ip
                self.name_template = name
                self.vendor = vendor
                self.library = library
                self.version = version
                self.name = None
                return
            # ------------------------------------------------------------------

            # -------------------------------`----------------------------------
            # Add the Package IP command line arguments to the parser
            # ------------------------------------------------------------------

            @staticmethod
            def add_arguments(parser):   # Package.Ip
                parser.add_argument(
                    '--ip_package',
                    help='Package Name',
                    action='append',
                    dest='package')
                parser.add_argument(
                    '--ip_vendor',
                    help='Package Vendor',
                    dest='vendor')
                parser.add_argument(
                    '--ip_library', help='Library', dest='library')
                parser.add_argument(
                    '--ip_version',
                    help='Version Number',
                    dest='version')

                return
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Print the package IP specification
            # ------------------------------------------------------------------

            def print(self, printer):     # Package.Ip

                # This is printed with configuration/component
                # if self.name : print (f"\n{'Name'          :{n}s}: {self.name}")

                print()
                printer.line('Ip    .Vendor', self.vendor)
                printer.line('      .Library', self.library)
                printer.line('      .Version', self.version)
                return
            # ------------------------------------------------------------------

            name_template: str
            name: str
            vendor: str
            library: str
            version: str
        # ----------------------------------------------------------------------
        # END: Product.Package.Ip
        # ---------------------------------------------------------------------


        # ----------------------------------------------------------------------
        # Manages the package Output specification
        # ----------------------------------------------------------------------
        class Output:

            # ------------------------------------------------------------------
            # Construct the output specification
            # ------------------------------------------------------------------
            def __init__(self, format, syn):   # Package.Output
                self.format = format
                self.syn = syn
                return
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Add the package output command line parameters to the parser
            # ------------------------------------------------------------------
            @staticmethod
            def add_arguments(parser):        # Package.Output
                return
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Print the package output specification
            # ------------------------------------------------------------------
            def print(self, printer):         # Package.Output

                print()
                printer.line('Output.format', self.format)
                printer.line('      .syn', 'True' if self.syn else 'False')
                return
            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # Add the package command line parameters to the parser
            # ------------------------------------------------------------------

            @staticmethod
            def add_arguments(parser):       # Package.Output
                parser.add_argument('--format', help='Output format')
                parser.add_argument(
                    '--syn',
                    action='store_true',
                    help='Synthesis Output')
                return
            # ------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # END: Product.Output
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # Add package to configuration
        # ----------------------------------------------------------------------
        def add(self, cfg_file):         # Package

            # -----------------------------
            # Deprecated starting at 2026.1
            # -----------------------------
            if Version.version < '2026.1':
                cfg_file.set_value(section='hls',
                                   key='flow_target',
                                   value='vivado')

            cfg_file.set_value(section='hls',
                               key='package.ip.name',
                               value=self.ip.name)

            cfg_file.set_value(section='hls',
                               key='package.ip.vendor',
                               value=self.ip.vendor)
            cfg_file.set_value(section='hls',
                               key='package.ip.library',
                               value=self.ip.library)

            cfg_file.set_value(section='hls',
                               key='package.ip.version',
                               value=self.ip.version)

            cfg_file.set_value(section='hls',
                               key='package.output.format',
                               value=self.output.format)

            cfg_file.set_value(section='hls',
                               key='package.output.syn',
                               value=self.output.syn)

            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        @staticmethod
        def add_arguments(parser):           # Package
            Product.Package.Ip.    add_arguments(parser)
            Product.Package.Output.add_arguments(parser)
            return
        # ----------------------------------------------------------------------


        # ---------------------------------------------------------------------

        def print(self, printer):                  # Package
            self.ip    .print(printer)
            self.output.print(printer)
            return
        # ----------------------------------------------------------------------


        # ----------------------------------------------------------------------
        def __init__(self, ip, output):     # Package
            self.ip = ip
            self.output = output
            return

        ip: Ip
        output: Output
        # ------------------------------------------------------------------

    # ----------------------------------------------------------------------
    # END: Product.Package
    # ----------------------------------------------------------------------


    # ----------------------------------------------------------------------
    def __init__(self, project, components, package, vivado): # Product

        # ----------------------------------------------------------------
        # Targets are precompiled components, i.e. they have not had their
        # logical symbols resolved yet.
        # ---------------------------------------------------------------
        self.targets = components
        self.project = project
        self.project.package = package
        self.project.vivado = vivado

        return
    # ----------------------------------------------------------------------


    # ----------------------------------------------------------------------
    def print(self, printer, quiet):  # Product
        self.package.print(printer)
        self.vivado. print(printer)
        return

    def add(self, cfg_file):          # Product
        self.package.add(cfg_file)
        self.vivado.add(cfg_file)
        return
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# END: Product
# ------------------------------------------------------------------------------
