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
from pathlib import Path
from string import Template
import vitis

from .workspace import Workspace
from .version import Version
from .component import Component
from .project import Project


# ------------------------------------------------------------------------------
# Class holding parameters common to all configurations
# ------------------------------------------------------------------------------
class Configuration:

    # --------------------------------------------------------------------------
    # Construction the generic configuration specification
    # --------------------------------------------------------------------------
    def __init__(self, args, create_components, project, product):

        configurations = project.configurations
        if configurations:
            configurations = os.path.expandvars(configurations)

        self.workspace = Workspace.get(project.workspace)
        self.configurations = configurations
        self.project = project
        self.spc_print = project.spc_print
        self.dry_run = args.dry_run
        self.verbose = args.verbose
        self.create = args.create is not None
        self.replace = args.replace is not None

        if create_components:
            self.comp = Component(project, args, self.workspace)
        else:
            self.comp = None
            self.client = None

        # ---------------------------------------------------
        # Currently only need a Vitis client if
        #  1. not a dry_run
        #  2. doing a create or replace
        #
        # This accomplishes to goals
        #  1. speeds up the process, client creation is slow
        #  2. more importantly, client creation will fail if
        #     the Vitis IDE/GUI is running
        # ---------------------------------------------------
        if not self.dry_run and (self.create or self.replace):
            self.client = vitis.create_client()

            # Only need to set the workspace if have components
            self.set_workspace(self.client)

        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def print_common(self, printer, verbose):

        caption = ('Creating Configuration' if self.create else
                   'Replacing Configuration')
        if self.comp:
            caption += ' + Component'

        printer.header(caption)

        if (self.workspace):
            printer.line("Workspace", self.workspace)

        self.project.print_project(printer, verbose)

        if self.verbose:

            if self.project.spc_print and self.project.spc_print.com_print:
                print()
                for item in self.project.spc_print.com_print:
                    if item[1]:
                        itm = item[1]
                        if item[2]:
                            itm = os.path.realpath(os.path.expandvars(itm))

                        printer.line(item[0], itm)

        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def print_argv(printer, label, argv):

        sep = ':'
        prefix = ''
        opts = argv.split(' -')

        for opt in opts:
            if len(opt):
                printer.itemPlain(label, prefix + opt, sep)
                label = ''
                sep = ''
                prefix = ' -'
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # Print the configuration specification parameters
    # --------------------------------------------------------------------------

    def print(self, printer, idx, target, status, seps, message, verbose):

        sep = seps[0] if status else seps[1]
        printer.item(idx, "Configuration", target.cfg_path, sep)

        if self.comp:
            failure = (not status and (len(message) == 2))
            sep = seps[0] if not failure else seps[1]
            printer.itemPlain("Component", self.comp.cmp_dir, sep)

        if not verbose:
            return

        # ----------------------------
        # Project specific information
        # ----------------------------
        if self.project.spc_print and self.project.spc_print.cfg_print:
            for item in self.project.spc_print.cfg_print:
                if len(item) == 0:
                    continue
                if item[1]:
                    itm = item[1].format(target_path=target.tgt_path,
                                         target_name=target.tgt_name)
                    if item[2]:
                        itm = os.path.realpath(os.path.expandvars(itm))
                    printer.itemPlain(item[0], itm)

        printer.itemPlain("Fpga", target.fpga)

        if self.verbose:
            printer.itemPlain("Package.name", self.project.package.ip.name)
            printer.itemPlain("Top HLS", self.top)

            if hasattr(self, 'sim_argv') and self.sim_argv:
                self.print_argv(printer, "Sim_argv", self.sim_argv)

            if hasattr(self, 'csim_argv') and self.csim_argv:
                self.print_argv(printer, "CSim_argv", self.csim_argv)

            if hasattr(self, 'cosim_argv') and self.cosim_argv:
                self.print_argv(printer, "CoSim_argv", self.cosim_argv)

        if (self.dry_run):
            printer.itemPlain("Action", "Dry Run <-- Note", '*')

        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def execute(self, target):

        map = target.map
        build = target.build
        cmp_name = target.cmp_name
        cfg_name = target.cfg_name
        cfg_path = target.cfg_path

        # -----------------------------------
        # Resolve the target dependent values
        # -----------------------------------
        self.top = build.top

        if hasattr(build, 'ldflags'):
            self.ldflags = build.ldflags
        else:
            self.ldflags = None

        # ------------------------------------
        # Programmatically set desired options
        # ------------------------------------
        if hasattr(build, 'sim'):
            sim_argv = build.sim_argv
            if sim_argv:
                self.sim_argv = sim_argv.format_map(target.map)
            else:
                self.sim_argv = None
        else:
            self.sim_argv = None

        if build.csim_argv:
            csim_argv = build.csim_argv
            if csim_argv:
                self.csim_argv = csim_argv.format_map(target.map)
            else:
                self.csim_argv = None
        else:
            self.csim_argv = None

        if build.cosim_argv:
            cosim_argv = build.cosim_argv
            if cosim_argv:
                self.cosim_argv = cosim_argv.format_map(target.map)
            else:
                self.cosim_argv = None
        else:
            self.cosim_argv = None

        # -------------------------------------------------------------------
        # Complete package IP
        # None was initially give, then take it from the cfg_path's file name
        # -------------------------------------------------------------------
        if self.project.package.ip.name_template is None:
            self.project.package.ip.name = cfg_name
        else:
            self.project.package.ip.name = (
                self.project.package.ip.name_template.format_map(target.map))

        exists = Path(target.cfg_path).is_file()
        if (exists):
            if (not self.replace):
                message = "WARNING: Using existing, (add --replace to replace)"
                if self.comp:
                    status, cfg_added, msg = self.comp.execute(self.client,
                                                               target.cmp_name,
                                                               target.cfg_path)
                    return False, [message, msg]
                else:
                    return False, [message]

        self.fpga = target.fpga
        if not self.dry_run:

            inc_dir = os.path.join(self.project.products_root, 'include')
            if not os.path.isdir(inc_dir):
                if not os.path.exists(inc_dir):
                    os.mkdir(inc_dir)

            import_file = os.path.join(inc_dir, 'import_file.hh')
            if os.path.exists(import_file):
                os.remove(import_file)

            with open(import_file, 'w') as file:
                file.write("#define HLSBS_QUOTE_IT(_x) #_x\n"
                           "#define IMPORT_FILE(_x) HLSBS_QUOTE_IT(_x)")
            self.import_file = import_file

            cfg_file = self.client.get_config_file(path=cfg_path)

            # --------------------------------
            # Fpga Part + clock + uncertainity
            # --------------------------------
            self.fpga.add(cfg_file)

            # ---------------------
            # Package (IP + Output)
            # ---------------------
            self.project.add(cfg_file)

            # ------------------------------------------------
            # Add the specific configuration the build sources
            # ------------------------------------------------
            self.add_sources(build,
                             cfg_file,
                             cfg_name,
                             cmp_name,
                             self.workspace,
                             map,
                             self.import_file)

        # -------------------------------------
        # Create the HLS component if requested
        # -------------------------------------
        if (self.comp) and not self.dry_run:
            status, ignore, msg = self.comp.execute(self.client,
                                                    target.cmp_name,
                                                    target.cfg_path)
            if (exists):
                return True, ["Replaced", msg]
            else:
                return True, ["Created", msg]

        elif self.comp and self.dry_run:
            self.comp.cmp_dir = os.path.join(self.workspace, target.cmp_name)

        if (exists):
            return True, ["Replaced"]
        else:
            return True, ["Created"]

    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # Compose cfg path by adding the extension if it is missing
    # ---------------------------------------------------------

    @staticmethod
    def compose_path(cfg_file):

        extension = os.path.splitext(cfg_file)[1]
        if (extension):
            return cfg_file
        else:
            return cfg_file + '.cfg'
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # Sets the workspace iff a component is to be generated

    def set_workspace(self, client):
        if self.comp:
            Workspace.set(client, self.comp.workspace)
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def make_relative(file, rel_path, expand=True):
        if expand:
            file = os.path.expandvars(file)
        file = os.path.relpath(os.path.realpath(file), rel_path)
        return file
    # --------------------------------------------------------------------------

    class SafeDict (dict):
        def __missing__(self, key):
            return f"{{{key}}}"  # Returns the original placeholder like {key}

    @staticmethod
    def expand_incs(includes,
                    cmp_name,
                    rel_path,
                    src_file):

        incs = ''
        errs = 0

        if not isinstance(includes, (list, tuple)):
            includes = (includes,)

        for inc in includes:
            paths = inc.paths
            dtype = inc.type

            if not isinstance(paths, (list, tuple)):
                paths = [paths]
            for path in paths:
                path = path.format_map(map)
                exp_path = os.path.expandvars(path)

                if dtype == 'abs_path':
                    inc_path = exp_path
                    inc_dir = '/' + path

                elif dtype == 'rel_path':

                    if os.path.isabs(exp_path):
                        inc_dir = Configuration.make_relative(exp_path,
                                                              rel_path,
                                                              True)
                        inc_path = os.path.join(rel_path, exp_path)
                    else:
                        inc_path = exp_path
                        inc_dir = path

                # -----------------------------
                # Check the include path exists
                # -----------------------------
                exists = os.path.isdir(inc_path)
                if not exists:
                    print(f"ERROR: inc_path = {inc_path} does not exist\n"
                          f"     : exp_path = {exp_path}\n"
                          f"     : rel_path = {rel_path}\n"
                          f"     : src_file = {src_file}\n"
                          f"     : cmp_name = {cmp_name}\n"
                          f"     : type     = {dtype}", file=sys.stderr)
                    errs += 1

                incs += ' -I ' + inc_dir

        return errs, incs
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def include_add(need_import, import_file, rel_path, dname, file):
        defs = ''
        if need_import:
            import_file = os.path.relpath(
                os.path.realpath(import_file), rel_path)
            defs += " -include " + import_file

        defs += " -D" + dname + "=" + file
        return defs
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def expand_defs(defines,
                    cmp_name,
                    src_file,
                    map,
                    import_file):

        # ------------------------------------------------------------
        # !!! KLUDGE !!!
        # This is sloppy, these values should come from the dictionary
        # ------------------------------------------------------------
        src_dir = os.path.split(src_file)[0]
        defs = ''
        errs = 0
        need_quote = True

        for d in defines:
            dname = d.name
            dtype = d.type

            # ---------------------------
            # Define is just a flag value
            # ---------------------------
            if dtype == 'flag':
                defs += ' -D' + dname
                continue

            value = d.value

            # -----------------------------------
            # All remaining types require a value
            # -----------------------------------
            if not value:
                print(
                    f"ERROR: {dname} define of type {dtype} missing the required value\n"
                    f"   ->: {src_file}")
                errs += 1

            # ---------------------------
            # Define -> -D <Name>=<Value>
            # ---------------------------
            if dtype == 'string':
                define = ' -D ' + dname
                define += '=' + value.format_map(map)
                defs += define
                continue

            # ---------------------------------------
            # Define is an including an absolute file
            # ---------------------------------------
            elif dtype == 'abs_file':
                # If value begins with '{' treat as substition value, else use
                # as is
                file = value.format_map(map) if value[0] == '{' else value
                abs_file = os.path.expandvars(file)
#                file     = '\"' + file + '\"'
                exists = os.path.isfile(abs_file)
                if not exists:
                    print
                    (f"ERROR: {dname} define type {dtype} file does not exist\n"
                     f"     : {abs_filefile}\n"
                     f"   ->: {src_file}\n")
                    errs += 1
                    continue

                if need_quote:
                    defs += "' -DHLSBS_QUOTE\\(_x\\)=#_x'"
                    need_quote = False

                defs += ' -D' + dname + '=HLSBS_QUOTE\\(' + file + '\\)'

            # -------------------------------------------------
            # Define is including a file relative to the source
            # -------------------------------------------------
            elif dtype == 'rel_file':
                # If value begins with '{' treat as substition value, else use
                # as is
                file = value.format_map(map) if value[0] == '{' else value
                exp_file = os.path.expandvars(file)
                rel_path = os.path.expandvars(
                    d.rel_path.format_map(map))

                if os.path.isabs(exp_file):
                    abs_file = exp_file
                    rel_file = Configuration.make_relative(file, rel_path)
                else:
                    rel_file = file
                    abs_file = os.path.realpath(os.path.join(rel_path,
                                                             exp_file))

                exists = os.path.isfile(abs_file)
                print
                if not exists:
                    print(
                        f"ERROR: {dname} define type {dtype} file does not exist\n"
                        f"     : {file}\n"
                        f"     : {rel_path}\n"
                        f"     : {rel_file}\n"
                        f"   ->: {abs_file}\n")
                    errs += 1
                    continue

                defs += Configuration.include_add(need_quote,
                                                  import_file,
                                                  rel_path,
                                                  dname,
                                                  rel_file)
                need_quote = False

            # --------------------------
            # Error: Unknown define type
            # --------------------------
            else:
                print(
                    f"ERROR:  Type  = {dtype} is not a recognized define type\n"
                    f"     :  Name  = {dname}\n"
                    f"     : Value = {value}\n"
                    f"    -> {src_file}", file=sys.stderr)
                errs += 1

        return errs, defs
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def _add_sources(cfg_file,
                     cfg_name,
                     cmp_name,
                     workspace,
                     map,
                     cfg_path,
                     sources,
                     label,
                     import_file):

        errors = 0
        first = True
        key_file = label + '.file'
        key_cflags = label + '.file_cflags'

        for source in sources:

            for file in source.files:
                file_path = os.path.expandvars(file)
                exists = os.path.isfile(file_path)
                errs = 0
                incs = None
                defs = None

                if not exists:
                    print(f"ERROR: In {label} files, file does not exist\n"
                          f"   ->  {file_path}\n",
                          file=sys.stderr)
                    errs = 1
                    errors += 1
                    continue

                cc_file = Configuration.make_relative(file_path,
                                                      cfg_path,
                                                      False)
                # -------------------------------
                # Add the include paths, -I <path>
                # -------------------------------
                if source.includes:
                    inc_errs, incs = Configuration.expand_incs(source.includes,
                                                               cmp_name,
                                                               cfg_path,
                                                               file_path)
                    errors += inc_errs
                    errs += inc_errs

                # ------------------------------------------------
                # Add the defines, i.e. -D <Name>, -D <Name=Value>
                # ------------------------------------------------
                if source.defines:
                    def_errs, defs = Configuration.expand_defs(source.defines,
                                                               cfg_name,
                                                               file_path,
                                                               map,
                                                               import_file)
                    errors += def_errs
                    errs += def_errs

                # ------------------------------------------------------------
                # Skip writing anything to the output file if there are errors
                # ------------------------------------------------------------
                if errs:
                    continue

                # --------------------------------------------------------------
                # Construct the cflags text strings for the includes and defines
                # --------------------------------------------------------------
                cflags = None
                if incs or defs:
                    cflags = cc_file + ','
                    if incs:
                        cflags += incs
                    if defs:
                        cflags += defs

                # -----------------------------------------
                # Bizarrely must write the subsequent files
                # with a different method than the first
                # -----------------------------------------
                if first:
                    cfg_file.set_value(section='hls',
                                       key=key_file,
                                       value=cc_file)
                    if cflags:
                        cfg_file.set_value(section='hls',
                                           key=key_cflags,
                                           value=cflags)
                    first = False
                else:
                    cfg_file.add_values(section='hls',
                                        key=key_file,
                                        values=[cc_file])
                    if cflags:
                        cfg_file.add_values(section='hls',
                                            key=key_cflags,
                                            values=[cflags])

        return errors
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def add_sources(self,
                    build,
                    cfg_file,
                    cfg_name,
                    cmp_name,
                    workspace,
                    map,
                    import_file):

        errs = 0

        cfg_file.set_value(section='hls', key='syn.top', value=self.top)

        cfg_path = os.path.realpath(os.path.split(cfg_file.path)[0])

        # --------------
        # Test Bed Files
        # --------------
        tbs = build.tb
        errs += self._add_sources(cfg_file,
                                  cfg_name,
                                  cmp_name,
                                  workspace,
                                  map,
                                  cfg_path,
                                  tbs,
                                  'tb',
                                  import_file)

        # ---------------
        # Synthesis Files
        # ---------------
        syns = build.syn
        errs += self._add_sources(cfg_file,
                                  cfg_name,
                                  cmp_name,
                                  workspace,
                                  map,
                                  cfg_path,
                                  syns,
                                  'syn',
                                  import_file)

        # -------------------
        # Abort if any errors
        # -------------------
        if errs:
            sys.exit(-1)

        # ------------
        # Linker flags
        # ------------
        if self.ldflags:
            key = 'tb.ldflags' if Version.version == 2023.2 else 'csim.ldflags'
            cfg_file.set_value(section='hls',
                               key=key,
                               value=self.ldflags)

        # -----------
        # Argv values
        # -----------
        if self.sim_argv:
            cfg_file.set_value(section='hls',
                               key='sim.argv',
                               value=self.sim_argv)

        if self.csim_argv:
            cfg_file.set_value(section='hls',
                               key='csim.argv',
                               value=self.csim_argv)

        if self.cosim_argv:
            cfg_file.set_value(section='hls',
                               key='cosim.argv',
                               value=self.cosim_argv)

        return
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
