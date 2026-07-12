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
import vitis

from .workspace import Workspace
from .version import Version
from .component import Component


# ------------------------------------------------------------------------------
# Class holding parameters common to all configurations
# ------------------------------------------------------------------------------
class Configuration:

    # --------------------------------------------------------------------------
    # Construct the generic configuration specification
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
        # This accomplishes two goals
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
        prefix = '-'
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
            printer.itemPlain("Component",  self.comp.cmp_dir, sep)

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
            printer.itemPlain("Package.name",  self.project.package.ip.name)
            printer.itemPlain("Top HLS",       self.top)

            if hasattr(self,    'sim_argv') and self.sim_argv:
                self.print_argv(printer, "Sim_argv",   self.sim_argv)

            if hasattr(self,  'csim_argv') and self.csim_argv:
                self.print_argv(printer, "CSim_argv",  self.csim_argv)

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
        self.top = build['top']

        if 'ldflags' in build:
            self.ldflags = build['ldflags']
        else:
            self.ldflags = None

        # ------------------------------------
        # Programmatically set desired options
        # ------------------------------------
        if 'sim_argv' in build:
            sim_argv = build['sim_argv']
            if sim_argv:
                self.sim_argv = sim_argv.format_map(target.map)
            else:
                self.sim_argv = None
        else:
            self.sim_argv = None

        if 'csim_argv' in build:
            csim_argv = build['csim_argv']
            if csim_argv:
                self.csim_argv = csim_argv.format_map(target.map)
            else:
                self.csim_argv = None
        else:
            self.csim_argv = None

        if 'cosim_argv' in build:
            cosim_argv = build['cosim_argv']
            if cosim_argv:
                self.cosim_argv = cosim_argv.format_map(target.map)
            else:
                self.cosim_argv = None
        else:
            self.cosim_argv = None

        # -------------------------------------------------------------------
        # Complete package IP
        # None was initially given, then take it from the cfg_path's file name
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

            cfg_file = self.client.get_config_file(path=cfg_path)

            # --------------------------------
            # Fpga Part + clock + uncertainty
            # --------------------------------
            self.fpga.add(cfg_file)

            # ---------------------
            # Package (IP + Output)
            # ---------------------
            self.project.add(cfg_file)

            # -------------------------------------------
            # Add the specific configuration to this file
            # -------------------------------------------
            self.add_files(build,
                           cfg_file,
                           cfg_name,
                           cmp_name,
                           self.workspace,
                           map)

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
                return True, ["Created",  msg]

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
        # realpath BOTH operands. Resolving the symlink on only one side (e.g. when
        # the repo is reached through a symlinked path such as /sdf/home -> /sdf/group)
        # made relpath climb to the common root and back down the real tree, producing
        # a broken cross-tree path in the tb.file / -I / #include cflags.
        file = os.path.relpath(os.path.realpath(file),
                               os.path.realpath(rel_path))
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
            paths = inc['paths']
            type = inc['type']

            if type != 'rel_path' and type != 'abs_path':
                print("ERROR: Include path type invalid for file\n"
                      f"    src_file  = {src_file}\n"
                      f"    cmp_name  = {cmp_name}\n"
                      f"        type  = \'{type}\' is not recognized\n"
                      f"       valid  = \'rel_path\' and \'abs_path\'\n"
                      f"       paths  = {paths}\n", file=sys.stderr)
                errs += 1
                continue

            if not isinstance(paths, (list, tuple)):
                paths = [paths]
            for path in paths:
                path = path.format_map(map)
                exp_path = os.path.expandvars(path)

                if type == 'abs_path':
                    inc_path = exp_path
                    inc_dir = '/' + path

                elif type == 'rel_path':

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
                          f"     : type     = {type}", file=sys.stderr)
                    errs += 1

                incs += ' -I ' + inc_dir

        return errs, incs
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def expand_defs(defines,
                    cmp_name,
                    src_file,
                    map):

        # ------------------------------------------------------------
        # !!! KLUDGE !!!
        # This is sloppy, these values should come from the dictionary
        # ------------------------------------------------------------
        os.path.split(src_file)[0]
        defs = ''
        errs = 0

        if not isinstance(defines, list):
            defines = [defines]

        for d in defines:
            name = d['name']
            if 'type' in d:
                type = d['type']
            else:
                print(f"ERROR: define specfication '{name}' missing the required type, one of\n"
                      f"     : [flag | string]\n"
                      f"   ->: {src_file}\n")
                errs += 1
                continue

            # ---------------------------
            # Define is just a flag value
            # ---------------------------
            if type == 'flag':
                defs += ' -D' + name
                continue

            value = d['value'] if 'value' in d else None

            # -----------------------------------
            # All remaining types require a value
            # -----------------------------------
            if not value:
                print(f"ERROR: {name} define of type {type} missing the required value\n"
                      f"   ->: {src_file}")
                errs += 1

            # ---------------------------
            # Define -> -D <Name>=<Value>
            # ---------------------------
            if type == 'string':
                define = ' -D ' + name
                define += '=' + value.format_map(map)
                defs += define
                continue

            # ---------------------------------------
            # Define is including an absolute file
            # ---------------------------------------
            elif type == 'abs_file':
                # If value begins with '{' treat as substitution value, else use as is
                file = value.format_map(map) if value[0] == '{' else value
                abs_file = os.path.expandvars(file)
                file = '\"' + file + '\"'
                exists = os.path.isfile(abs_file)
                if not exists:
                    print(f"ERROR: {name} define type {type} file does not exist\n"
                          f"     : {abs_file}\n"
                          f"   ->: {src_file}\n")
                    errs += 1
                    continue

                defs += ' -D' + name + '=' + file

            # -------------------------------------------------
            # Define is including a file relative to the source
            # -------------------------------------------------
            elif type == 'rel_path':
                # If value begins with '{' treat as substitution value, else use as is
                file = value.format_map(map) if value[0] == '{' else value
                exp_file = os.path.expandvars(file)
                rel_path = os.path.expandvars(
                    d['rel_path']).format_map(map)

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
                        f"ERROR: {name} define type {type} file does not exist\n"
                        f"     : {file}\n"
                        f"     : {rel_path}\n"
                        f"     : {rel_file}\n"
                        f"   ->: {abs_file}\n")
                    errs += 1
                    continue
                # Emit the path BARE (no quotes). csim cflags pass through a
                # shell but cosim re-tokenizes them without one, so any quoting
                # here survives csim yet reaches the cosim compiler literally
                # (breaking `#include MACRO`). A bare, shell-neutral value is
                # identical in both; the testbench stringizes it for #include.
                defs += ' -D' + name + '=' + rel_file

            # --------------------------
            # Error: Unknown define type
            # --------------------------
            else:
                print(
                    f"ERROR: Type  = {type} is not a recognized define type\n"
                    f"     :  Name  = {name}\n"
                    f"     : Value = {value}\n"
                    f"    -> {src_file}", file=sys.stderr)
                errs += 1

        return errs, defs
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def _add_files(cfg_file,
                   cfg_name,
                   cmp_name,
                   workspace,
                   map,
                   cfg_path,
                   files,
                   label):

        errors = 0
        first = True
        key_file = label + '.file'
        key_cflags = label + '.file_cflags'

        for file in files:

            file_path = os.path.expandvars(file['files'])
            exists = os.path.isfile(file_path)
            if not exists:
                print(f"ERROR: {file['files']} does not exist\n"
                      f"   ->  {file_path}\n",
                      file=sys.stderr)
                errors += 1
                continue

            cc_file = Configuration.make_relative(file_path,
                                                  cfg_path,
                                                  False)

            # -------------------------------
            # Add the include paths, -I <path>
            # -------------------------------
            if 'includes' in file:
                errs, incs = Configuration.expand_incs(file['includes'],
                                                       cmp_name,
                                                       cfg_path,
                                                       file_path)
                errors += errs

            # ------------------------------------------------
            # Add the defines, i.e. -D <Name>, -D <Name=Value>
            # ------------------------------------------------
            if 'defines' in file:
                errs, defs = Configuration.expand_defs(file['defines'],
                                                       cfg_name,
                                                       file_path,
                                                       map)
                errors += errs
            else:
                errs = 0
                defs = None

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

    def add_files(self,
                  build,
                  cfg_file,
                  cfg_name,
                  cmp_name,
                  workspace,
                  map):

        errs = 0

        cfg_file.set_value(section='hls', key='syn.top', value=self.top)

        cfg_path = os.path.realpath(os.path.split(cfg_file.path)[0])

        # --------------
        # Test Bed Files
        # --------------
        tbs = build['tb']
        errs += self._add_files(cfg_file,
                                cfg_name,
                                cmp_name,
                                workspace,
                                map,
                                cfg_path,
                                tbs,
                                'tb')

        # ---------------
        # Synthesis Files
        # ---------------
        syns = build['syn']
        errs += self._add_files(cfg_file,
                                cfg_name,
                                cmp_name,
                                workspace,
                                map,
                                cfg_path,
                                syns,
                                'syn')

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
