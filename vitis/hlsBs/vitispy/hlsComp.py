# ------------------------------------------------------------------------------
'''
    Creates/Removes/Queries HLS Components

    Args:
       @project_file  :  Gives the default workspace
       -w, --workspace:  Specifies the workspace, overriding the default

'''
# ------------------------------------------------------------------------------


import os
import sys
import argparse
import shutil
import runpy
import glob

# -------------------------------------------------------
# Add the VITIS HLS python paths, remove nonexistent ones
# ------------------------------------------
runpy.run_path (os.getenv ('HLS_PROJECT_IMPORT_PYPATHS'),
                run_name = 'add_paths ' + str(sys.path))
import vitis
from   vitispy.manpage       import display_manpage
import vitispy.files         as     files
from   vitispy.printer       import Printer
from   vitispy.workspace     import Workspace
from   vitispy.action        import Action
from   vitispy.dry_run       import DryRun
from   vitispy.version       import Version
from   vitispy.project       import Project
from   vitispy.targets       import Targets
from   vitispy.category      import Category
from   vitispy.componentInfo import ComponentInfo

# ==============================================================================
#
# This creates, replaces, cleans, lists components in a workspace
#
# ==============================================================================


# ==============================================================================
# BEGIN: Local methods
# ------------------------------------------------------------------------------
def add_arguments (parser) :
    Project.  add_arguments (parser)
    Workspace.add_arguments (parser)
    DryRun.   add_arguments (parser)
    Action.   add_arguments (parser, 'Components')

    parser.add_argument ('-h',
                         '--help',
                         action = 'store_true',
                         help   = 'Show custom help')

    parser.add_argument ('parameters',
                         help    = 'List of targets/components',
                         nargs   = '*',
                         action  = 'store',
                         default =  None)

    parser.add_argument ('--verbose',
                         action  = 'store_true',
                         default = False)

    parser.add_argument ('--targets',
                         help    = 'Inputs are targets',
                         nargs   = '?',
                         const   = '*_no_value_*',
                         default =  None)

    parser.add_argument ('--components',
                         help    = 'Manual entry of components to create',
                         nargs   = '?',
                         const   = '*_no_value_*',
                         default = None)

    parser.add_argument ('--configurations',
                         help    = 'Manual entry of target configurations',
                         nargs   = '?',
                         const   = '*_no_value_*',
                         default = None)

    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def get_opts (action, args) :
    if   action & Action.List :
        label   = 'Listing'
        opts    = Category.categorize (args.list, Category.All)

    elif action & Action.Clean :
        label   = 'Cleaning'
        opts    = Category.categorize (args.clean, Category.Existing)

    elif action & Action.Replace :
        label   = 'Replacing'
        opts    = Category.categorize (args.replace, Category.Existing)

    elif action & Action.Create :
        label   = 'Creating'
        opts    = Category.categorize (args.create, Category.Missing)

    else :
        label       = 'Creating'
        args.create = ['nissing']
        opts        = Category.categorize (args.create, Category.Missing)

    return label, opts
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def get_client (action, workspace, targets) :
    if action & (Action.Create | Action.Replace) :
        for target in targets :
            cfg_exists = os.path.isfile (target.cfg_path)

            # Create create component with no cfg
            if not cfg_exists : continue

            cmp_exists = os.path.isdir  (target.cmp_path)

            # Can't create if cmp already exists
            if action & Action.Create and cmp_exists : continue

            # Need to create the client
            client = vitis.create_client  ()
            Workspace.set (client, workspace)
            return client
    return None
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def noWorkspaceError () :
    print (
    '''
    ERROR: No workspace was provided
           add --workspace=<ws>
    ''',
    file = sys.stderr)
    return -1
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def nonExistentWorkspace (workspace) :
    print (
    "ERROR: Workspace does not exist\n"
    "       To avoid typos causing spurious creation, use hlsWs to create it\n"
    "\n"
    "  -->  " + workspace + "\n", file = sys.stderr)
    return -1
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def noCompleteCleanWarning () :
    # Error message when an implicit '*' is used when cleaning
    print (
    '''
    WARNING: To avoid cleaning more than intended, hlsComp requires that
             postional args or --targets='*' must be specified, e.g.
               $ hlsCfg '*' --clean             or
               $ hlsCfg --targets='*'
    ''',
    file = sys.stderr)
    return -1
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def cmpExistsError (printer) :
    printer.itemPlain ('', "ERROR: component alreay exists, use --replace", '*')
    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def noCfgError (printer) :
    printer.itemPlain ('', 'ERROR: cannot replace component',          sep = '*')
    printer.itemPlain ('', '       configuration file does not exist', sep = ' ')
    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def noConfigurationList () :
    print ('''
           ERROR: No configuration target list provided
           ''',
           file = sys.stderr)
    return -1
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def noCompError (printer, workspace, tgtList) :
    all = sorted (files.get_components (workspace, '*'))

    if not all :
        printer.line ( "ERROR: No components found in workspace")
        printer.line (f"       {workspace}")

    else :
        printer.line (f"ERROR: No components found matching <{tgtList}>")
        printer.line ("Candidates are:")

        idx = 1
        for component in all :
            cmp_name = os.path.splitext (os.path.split (component)[1])[0]
            printer.item (idx, cmp_name, None)
            idx += 1
    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Executer :
    def __init__ (self,
                  action,
                  printer,
                  verbose,
                  opts,
                  workspace,
                  categories,
                  dry_run) :

        self.action      = action
        self.printer     = printer
        self.verbose     = verbose
        self.opts        = opts
        self.workspace   = workspace
        self.categories  = categories
        self.dry_run     = dry_run
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def byCategories (self, client) :

        printer    = self.printer

        # ------------------------------------------------------
        # Only print dry run if it causes some 'write' activity'
        # ------------------------------------------------------
        if  self.dry_run is not None and self.dry_run:
            self.printer.line   ('Dry Run', '<-- NOTE')
        self.printer.separator ('-')

        lf = False
        if self.opts & Category.Existing :
            printer.line ('Existing')
            lf = self.execute (client, self.categories.existing, True)

        if self.opts & Category.Missing :
            if lf : print ()
            self.printer.line ('Missing Component')
            lf = self.execute (client, self.categories.missing, True)

        if self.opts & Category.Cruft :
            if lf : print ()
            lf  = False
            nlo = len (self.categories.cruft_lo)
            nhi = len (self.categories.cruft_hi)

            self.printer.line ('No Configuration File')
            if (nlo == 0) and (nhi == 0) :
                self.printer.itemPlain ("None", "")

            if self.opts & Category.CruftHi and nhi:
                if lf : print ()
                lf = self.execute (client, self.categories.cruft_hi, False)

            if self.opts & Category.CruftLo and nlo:
                if lf : print ()
                lf = self.execute (client, self.categories.cruft_lo, False)

        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def execute (self,
                 client,
                 targets,
                 print_none) :

        printer   = self.printer

        if len (targets) == 0 and print_none :
            printer.itemPlain ('None', None, None)
            return True


        idx = 0
        lf  = True
        for target in targets :
            cfg_path   = target.cfg_path
            cmp_path   = target.cmp_path
            cmp_name   = target.cmp_name

            cfg_exists = os.path.isfile (cfg_path) if cfg_path else False
            cmp_exists = os.path.isdir  (cmp_path) if cmp_path else False
            cfg_sep    = ':' if cfg_exists else '*'
            cmp_sep    = ':' if cmp_exists else '*'

            if idx != 0 and lf : print ()
            idx += 1
            name = cmp_name
            if cmp_name is None :
                name = ("Component not present in workspace, "
                        "check cfg file as a possible stray")

            printer.item (idx, 'Component',  name, cmp_sep)
            if (cfg_path and self.verbose) or cmp_name is None :
                printer.itemPlain ('Configuration', cfg_path, cfg_sep)
            else :
                lf = False

            # ACTION = LIST
            if self.action & Action.List :
                # The list has effectively already been performed
                continue

            # ACTION = CLEAN
            if self.action & Action.Clean :
                if cmp_exists :
                    if not self.dry_run : shutil.rmtree (target.cmp_path)

            # ACTION = CREATE
            if self.action & Action.Create:
                if       cmp_exists : cmpExistsError (printer)
                elif not cfg_exists : noCfgError     (printer)
                else :
                    if self.dry_run : continue
                    client.create_hls_component (name     = cmp_name,
                                                 cfg_file = [cfg_path],
                                                 template = "empty_hls_component")

            # ACTION = REPLACE
            if self.action & Action.Replace:
                if not cfg_exists: noCfgError (printer)
                else :
                    if self.dry_run : continue

                    client.delete_component     (name     = cmp_name)
                    client.create_hls_component (name     = cmp_name,
                                                 cfg_file = [cfg_path],
                                                 template = "empty_hls_component")
        return True
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   Merges x, y into a list, where x,y can either by a list or a comma separated
   string
'''
def merge (xl, yl) :
    lst = []
    if xl :
        # Check if XL is a list
        if isinstance (xl, list) :
            for x in xl : lst +=  x.split (',')
        else            : lst  = xl.split (',')

    if yl:
        # Check if YL is a list
        if isinstance (yl, list) :
            for y in yl : lst +=  y.split (',')
        else            : lst += yl.split (',')

    return lst
# ------------------------------------------------------------------------------
# END  : Local methods
# ==============================================================================



# ==============================================================================
# BEGIN: Main execution
# ------------------------------------------------------------------------------
def doit () :

    # -------------------------------
    # Get the command line parameters
    # -------------------------------
    parser = argparse.ArgumentParser (add_help              = False,
                                      fromfile_prefix_chars ='@')
    add_arguments  (parser)

    args = parser.parse_args ()
    if args.help :
        display_manpage (__file__)
        exit (0)

    action        = Action (args).action
    dry_run       = args.dry_run
    cmpList       = merge (args.parameters, args.targets)

    # -------------------------------------------
    # Check if target list of components is empty
    # -------------------------------------------
    if  not cmpList :
        if action & Action.Clean : return noCompleteCleanWarning ()
        else                     : cmpList = ['*']


    label, opts   = get_opts (action, args)
    printer       = Printer (20, 78, 15)
    noCfgAction   = False
    full          = not args.configurations  and args.project is not None
    needs         = Project.Need.Workspace
    project_files = args.project if full else None

    project       = Project (Project.Need.Workspace,
                             project_files,
                             args.root,
                             args.products_root,
                             args.workspace)

    if  project.error :
        status = project.report (needs)
        return status

    if not full :
        # -----------------
        # Vet the arguments
        # -----------------
        if not args.configurations or len (args.configurations) == 0 :
            if not action & (Action.List | Action.Clean) :
                return noConfigurationList ()
            else :
                noCfgAction = True
    else :
        full = hasattr (project, 'get_products')

        # -------------------------------------------------------------
        # Override any project specific defaults with command line ones
        # -------------------------------------------------------------
        project.replace (args)


    # -----------------------------------------------------------------
    # Demand the workspace exists
    # Automatically creating is dangerous,
    # Doing so can unknowingly create and populate a mistyped workspace
    # which can easily go unnoticed
    # -----------------------------------------------------------------
    workspace = project.workspace
    exists    = os.path.isdir (workspace)
    if not exists :
        return nonExistentWorkspace (workspace)

    # ---------------------------------------------------
    # Check if doing list or clean with no configurations
    # ---------------------------------------------------
    if noCfgAction :
        opts       &= ~Category.Missing
        categories  = Category.categorizeByComponent (workspace, cmpList)


    # Check if doing the cheap version, i.e. do project products
    elif not full :
        if not args.components : args.components = '{cfg_name}'

        configurations = os.path.expandvars (args.configurations)
        components     = os.path.expandvars (args.components)
        categories     = Category.getCategories (workspace,
                                                 configurations,
                                                 components,
                                                 cmpList)
    else :

        # ---------------------------------------
        # To do create/replace, need the products
        # --------------------------------------

        project.get_products ()
        cmpTargets = project.products[0].targets
        targets    = Targets (workspace, cmpTargets).targets
        targets    = Targets.filter (targets, cmpList).accepts

        if  not targets :
            msg    = label + " Components"
            return Targets.no_candidate_targets (targets, msg, project)

        categories = Category.byComponents (targets)



    # ---------------------------------------------
    # Create HLS client only if necessary.
    # It is time wise expensive and dumps confusing
    # and unnecessary crap into the output
    # ---------------------------------------------
    client = None
    if  not dry_run :
        if  action & Action.Create :
            client = get_client (action,
                                 workspace,
                                 categories.missing)
        elif action & Action.Replace :
            client = get_client (action,
                                 workspace,
                                 categories.existing)

    if noCfgAction:
        printer.header (label + ' Components')
        printer.line   ('Workspace',          workspace)
        printer.line   ('Component Filter',   cmpList)

    elif not full:
        printer.header (label + ' Components')
        printer.line   ('Workspace',          workspace)
        printer.line   ('Configurations',     args.configurations)
        printer.line   ('Component Template', args.components)
        printer.line   ('Component Filter',   cmpList)
    else :
        printer.header (label + ' Components')
        printer.line   ('Workspace',          workspace)
        printer.line   ('Component Filter',   cmpList)

    if not categories :
        printer.footer ()
        return -1
    else :
        executer = Executer (action,
                             printer,
                             args.verbose,
                             opts,
                             workspace,
                             categories,
                             dry_run)
        executer.byCategories (client)
        printer.footer ()

        return 0
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
if (__name__ == '__main__') :
    status = doit ()
    sys.exit (status)
# ----------------------------------------------------------------------
