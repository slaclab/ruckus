
import sys
import re
import os
import fnmatch
import glob

if __name__ == "__main__" :
   sys.path.append (os.path.split (os.path.split (__file__)[0])[0])

   from   vitispy.version       import Version
   from   vitispy.maps          import Maps
   from   vitispy.project       import Project
   from   vitispy.componentInfo import ComponentInfo
   from   vitispy.printer       import Printer
else:
   from   .version       import Version
   from   .directory     import Directory
   from   .maps          import Maps
   from   .project       import Project
   from   .componentInfo import ComponentInfo
   from   .printer       import Printer


    
# -----------------------------------------------------------------------------
class TargetMin :
   def __init__ (self, cmp_name, cmp_path) :
      self.cmp_path = os.path.relpath (cmp_path)
      self.cmp_name = cmp_name
        
      cmp_info   = ComponentInfo (cmp_path, True)
      self.errs = cmpInfo.errs
      
      if cmp_info.errs :
         self.cfg_path = None
         self.cfg_name = None
      else :
         self.cfg_path = os.path.relpath (cmp_info.cfg_files[0])
         self.cfg_name = os.path.split (self.cfg_path)[1]
      return
# -----------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Target :
   '''
   A target is a candidate for an eventual build of HLS configuration file and
   its component. This method 
      - Adds the vitis version and the configuration name to the map
      - Resolves the originating target path and configuration and the
        component path.
   The component name (i.e. just the file name portion of the path) is used
   as the unique identifier for the target.  This identifier must be unique
   for this candidate target to be added to the list of targets

   '''
   def __init__ (self,
                 workspace,
                 map,
                 tgt_template,
                 cfg_template,
                 cmp_template) :
      '''
      Constructs a target candidate

      Args:
         workspace   :  The fully resolved path the VITIS/HLS  workspace
         map         :  The source of the unresolved definitions for this
                        target
         tgt_template:  Used to create the fully resolved name of the
                        originating target file
         cfg_template:  Used to create the fully resolved name of the HLS
                        configuration file
         cmp_template:  Used to create the fully resolved name of the HLS
                        conmponent directory within the workspace
      '''

      # ------------------------------------------------------------
      # Add the vitis version for any possible usage
      # Being a global it is not property of the target dictionaries
      # ------------------------------------------------------------
      map['vitis_version'] = Version.version

      self.map      = map
      self.build    = map['build']
      self.fpga     = map['fpga']

      self.cfg_path = os.path.realpath (cfg_template.format_map (map))
      self.cfg_name = os.path.split (os.path.splitext (self.cfg_path)[0])[1]

      # --------------------------------------------------------------
      # Add the cfg_name to map, this is used to add duplicate entries
      # into the list of targets
      # --------------------------------------------------------------
      map['cfg_name'] = self.cfg_name

      self.cmp_name   = cmp_template.format_map (map)
      self.cmp_path   = os.path.realpath (
                        os.path.join (workspace, self.cmp_name))

      if tgt_template :
         self.tgt_path = tgt_template.format_map (map)
         self.tgt_name = os.path.split (os.path.splitext (self.tgt_path)[0])[1]
      else :
         self.tgt_path = None
         self.tgt_name = None

      return
   # --------------------------------------------------------------------------


   # --------------------------------------------------------------------------
   def print (self) :
      print (f"cfg_path  = {self.cfg_path}\n"
             f"cfg_name  = {self.cfg_name}\n"
             f"component = {self.component}\n"
             f"build     = {self.build}\n",
             f"fpga      = {self.fpga}\n")
   # --------------------------------------------------------------------------
             
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Targets :

   # --------------------------------------------------------------------------
   '''
   Trims the list of all target candidates using a wildcard list to select.

   Args:
      targets:  The list of targets
      filters:  A single of list of strings containing the usual shell
                wildcards

   Returns:
      The trimmed list of candidates
   '''
   @staticmethod
   def filter (targets, filters) :

      class Filtered :
         def __init__ (self) :
            self.accepts  = []
            self.rejects  = []
            return
      
      # -------------------------------
      # If not list, convert it to one
      # ------------------------------
      if not isinstance (filters, (list, tuple)) : flts = filters.split (',')
      else                                       : flts = filters

      filtered = Filtered ()
      for target in targets :
         for flt in flts :
            match = fnmatch.fnmatch (target.cmp_name, flt)
            if match : filtered.accepts.append (target)
            else     : filtered.rejects.append (target)
               
      return filtered
   # --------------------------------------------------------------------------


   # --------------------------------------------------------------------------
   @staticmethod
   def no_candidate_targets (targets, action, project) :
      printer = Printer ()
      printer.header (f"{action}")
      printer.line   ( "ERROR: No candidates where formed by the project file")
      printer.line   ( "       This is likely due to a bad source file(s) product specifications")
      printer.line   ( "       Check the following project file(s)")
      idx = 1
      for prj_file in project.prj_files :
         printer.item (idx, prj_file, '')
         idx += 1

      return -1
   # --------------------------------------------------------------------------


   # --------------------------------------------------------------------------
   @staticmethod
   def no_user_targets (targets, action, tgtList) :
      printer = Printer ()
      printer.header    (f"{action}")
      printer.line      (f"ERROR: No targets found matching <{tgtList}>")
      printer.separator ('-')
      printer.line      ("Candidates are")

      idx = 1
      for target in targets :
         printer.item (idx, target.cmp_name, '')
         idx += 1
        
      printer.footer ()
      return -1
   # --------------------------------------------------------------------------

   
   # --------------------------------------------------------------------------
   def __init__ (self, workspace, products) :
      '''
      Populates the list of all possible targets.

      Args:
         workspace  :  The HLS Vitis workspace
         products   :  The list of products. This comes from the users
                       project file
      '''
      
      self.workspace = workspace
      self.targets   = []
      cmps           = []
      for product in products :
         for prd_target in product.targets:
         
            # -------------------------------------
            # Retrieve the target member infomation
            # -------------------------------------
            cfg_template = prd_target['ConfigurationName']
            cmp_template = prd_target[    'ComponentName']
            components   = prd_target[       'Components']
            maps         = Maps (components)

            cfg_template = os.path.expandvars (cfg_template)

            if 'Source' in prd_target :
               src_template = prd_target[       'Source']
               src_template = os.path.expandvars (src_template)
            else :
               src_template = None

            # Each map yields a target
            for map in maps.maps :

               target = Target (workspace,
                                map,
                                src_template,
                                cfg_template,
                                cmp_template)

               if not target.cmp_name in self.targets :
                  self.targets.append (target)
               else :
                  print (f"ERROR: duplicate component found {cmp}")

      self.targets.sort (key = lambda x : x.cmp_name)
      return
   # --------------------------------------------------------------------------


   # --------------------------------------------------------------------------
   def classify (workspace, products, targets, filters, configurations) :
      '''
      Classifies a potential configuration files as
         1. Existing -- a configuration file that both is accepted by the
                        filters
            and is known to this project and exists
         2. Missing  -- a configuration file that both is accepted by the
                        filters
            and is known to this project and but is absent 
         3. Cruft   --- A file in any of the directories with the file
                        extensions used by that directory used when creating
                        a configuration file

      Args:
        products       :  List of the project's products
        targets        :  List of the fully fleshed out known targets of this
                          project
        filters        :  List of wildcard specifications used to filter the
                          list of targets to those of current interest
        configurations :  Possible configuration template override

      Returns:
        A classification class giving lists of existing and missing targets and
        a list of 'cruft' files, i.e. files in directories known by the project
        to contain configuratin files

      CAVEAT
      The Existing and Missing catagories a hard concepts, i.e. 
         1. Either the file is known to be a target of this project or it isn't
         2. Either the file exists in the file system or it doesn't

      However being classified as 'Cruft' is done via 2 criteria. The first
      is a very sure way
         1. The components in the workspace are examined and to see if the json
            file contains a reference to the file

      If the corresponding component does not exist, this failes and a 
      heuristic method.

      By definition, such files are not known to the project, whether it is 
      configuration file or not cannot be definitely determined. Consider 2 
      files
      'file1.cfg' and 'file2.txt',  It only by some convention that 
      'file1.cfg' is thought to be a configuration file and 'file2.txt' is not.
      
      How some unknown file got there and the naming conventions used by its 
      producer are unknownable.  There are 2 ways to address this

        1. Demand the user provide a template giving the naming convenion.
           While formally correct this was deemed to burdensome and
           error-prone.
           In practice, no user is diligently going to maintain such a list

        2. Adopt the naming conventions of the current project, which is what
           has been chosen.

      Because of this, the user is encouraged to use consistent naming
      convention within a project. The most natural convention is to use a
      consistent file extension and while anything will do, the most natural
      extension is .cfg.
      '''

      class RemoveLocals (dict):
        def __missing__(self, key):
            return '*'  # Returns '*'

      class Cruft :
         def __init__ (self, cfg_path, cmp_path) :
            self.cfg_path = cfg_path
            self.cmp_path = cmp_path
            self.cmp_name = None
            if cmp_path :
               self.cmp_name = os.path.split (cmp_path)[1]
           
      class Categories :
         def __init__ (self) :
            self.existing = []
            self.missing  = []
            self.cruft_lo = []
            self.cruft_hi = []

      category = Categories ()
      if not isinstance (filters, (list, tuple)) : filters = (filters,)

      # --------------------------------------------------
      # Lists to keep track of what has already been seen
      # avoid duplicates, which is possible with wildcards
      # resolving to the same directory or file
      # --------------------------------------------------
      cfg_wcs   = []
      cmp_wcs   = []
      cfg_files = []
      cmps      = []

      # --------------------------------------------------
      # Check if there are accepted candidates then,
      # Initial the existing and cruft lists to empty and
      # presume all targets in the trimmed target list are
      # missing until proven otherwise.
      # --------------------------------------------------
      filtered = Targets.filter (targets, filters)
      if len (filtered.accepts) == 0:
         Targets.no_user_targets (filtered.rejected, 'classifying', filters)
         return None
      category.missing  = filtered.accepts          

      # -----------------------------------------------------------
      # This changes any target specfic symbol translation to '*'
      # Global symbol translation is still allowed
      # NOTE: Currently the only global symbol is the vitis version
      #       but this could change -> need to formalize what the
      #       global symbols are.
      # -----------------------------------------------------------
      remove_locals = RemoveLocals ({'vitis_version' : Version.version})
      ignore_paths  = (os.path.join (workspace, '_ide'),
                       os.path.join (workspace, 'logs') )


      # ----------------------------------------------------------------------
      # Scavenge for cruft in components in the workspace
      # -------------------------------------------------
      cmp_wc    = os.path.join (workspace, '*')
      cmp_paths = glob.glob (cmp_wc)
      for cmp_path in cmp_paths :

            
         # Ignore the _ide,logs, etc directories in the workspace
         if cmp_path in ignore_paths : continue
            
         # Component path must be a directory
         if not os.path.isdir (cmp_path) : continue

         cmp_info = ComponentInfo (cmp_path, True)
         if cmp_info.errs:
            # ----------------------------------------
            # The component is present
            # Check on its configuration file
            #   1) If not absent -> call cruft
            #   2( If     absent -> leave as missing
            # ----------------------------------------
            if not (cmp_info.errs & ComponentInfo.ErrNoCfgFile) :
               category.cruft_hi.append (Cruft (None, cmp_path))
               continue

         cfg_paths = cmp_info.cfg_files
         if not isinstance (cfg_paths, list) : cfg_paths = [cfg_paths]
         for cfg_path in cfg_paths :
            if cfg_path in cfg_files : continue
            cfg_files.append (cfg_paths)
                  
            # --------------------------------------
            # Check if in the pool of all candidates
            # --------------------------------------
            tgt = (next ((target for target in targets 
                       if target.cfg_path == cfg_path), None))

            if not tgt:
               category.cruft_hi.append (Cruft (cfg_path, cmp_path))
            else :
               # -----------------------------------------------
               # This is a legitimate target,
               # If in missing, promote from missing -> existing
               # -----------------------------------------------
               tgt = (next ((target for target in category.missing
                          if target.cfg_path == cfg_path), None))
               if tgt :
                  category.missing.remove  (tgt)
                  category.existing.append (tgt)
               else:
                  tgt = (next ((target for target in filtered.rejected
                          if target.cfg_path == cfg_path), None))

                  if not tgt :
                     category.cruft_hi.append (Cruft (cfg_path, cmp_path))
      # ---------------------------------------------------------------------

      # ---------------------------------------------------------------------
      # Processs each unexpanded project target
      # ---------------------------------------
      for product in products:
         product.configurations = configurations
         for prd_target in product.targets :
            # ---------------------------------------------------------------
            # Examine the contents of all the targets configuration
            # directories to see if there is an cruft in there. This is
            # somewhat heurestic, no way to do it completely right, so
            # it is not critical.
            # 
            # Retrieve the configuration template and isolate the directory
            # and file extension. This is where all files of interest are
            # thought to reside.
            #
            # At one time thought thought substituting the local symbols
            # as '*'
            #   e.g.  dir/{build_id}-{fpga_id}.cfg  -> dir/*-*.cfg
            # was the right thing to do.  Have decided to replace the name
            #   e.g.  dir/{build_id}-{fpga_id}.cfg  -> dir/*.cfg
            # ----------------------------------------------------------
            cfg_tmpname     = prd_target['ConfigurationName']
            cfg_template    = os.path.expandvars (cfg_tmpname)
            #cfg_template    = cfg_template.format_map (remove_locals)
            cfg_dir, namext = os.path.split (cfg_template)
            cfg_ext         = os.path.splitext (namext)[1]
            cfg_wc          = os.path.join (cfg_dir, '*') + cfg_ext
            cfg_wc          = os.path.realpath (cfg_wc)

            # -----------------------------------------
            # If have already seen this cfg_wc, move on
            # -----------------------------------------
            if cfg_wc in cfg_wcs : continue

            # -----------------------------
            # New cfg_wc, get all the files
            # -----------------------------
            cfg_wcs.append (cfg_wc)
            files = glob.glob (cfg_wc)
         
            for file in files :
               # ---------------------------------------
               # If have already seen this file, move on
               # ---------------------------------------
               if file in cfg_files : continue

               # ------------------------
               # Check if in the existing
               # ------------------------
               tgt = (next ((target for target in category.existing
                          if target.cfg_path == file), None))

               if tgt :
                  # ------------------------------------------
                  # Target is exists, so already accounted for
                  # ------------------------------------------
                  continue

               # --------------------------------------
               # Not in the pool of existing components
               # Make sure not already seen
               # --------------------------------------
               if (any((cruft for cruft in category.cruft_hi
                     if cruft.cfg_path == file))) : continue
                             

               # ---------------------------------------------------
               # Check if in the pool of known, but rejected targets
               # If so, it is not 'cruft', just not of interest.
               # -----------------------------------------------
               tgt = (any((target for target in filtered.rejects
                              if target.cfg_path == file)))
               if not tgt :
                  # --------------------------------------------------------
                  # Completely unknown file, but it does fit the pattern for
                  # a configuration file so classify it as cruft leftover
                  # from some previous project populating the directory
                  # --------------------------------------------------------
                  category.cruft_lo.append (Cruft (file, None))

      return category
# ------------------------------------------------------------------------------


              

# ------------------------------------------------------------------------------
if __name__ == "__main__" :

   breakpoint ()
   # ----------------------------
   # Simple test/debugging method
   # ----------------------------
   project_file = os.path.expandvars ("$HLS_PROJECT_PRJ")
   needs   = 0
   project = Project (needs,
                      project_file,
                      None,
                      None,
                      None)


   workspace = 'tmp/jj/ws'

   
   # ------------------------------------------------------
   # Retrieve the candidate products and form their targets
   # -----------------------------------------------------
   project.get_products ()
   
   tgt      = Targets (workspace, project.products)
   targets  = tgt.targets
   
   print ("All targets")
   for target in targets :
      print (target.cmp_name)

   
   trim = sys.arg[1] if (len (sys.argv) >  1) else '*'
   classes = Targets.classify (workspace, project.products, targets, trim, None)
   print (f"\n\nResults")
   for _ in classes.existing : print (f"present  = {_.cfg_path}")
   for _ in classes.missing  : print (f"missing  = {_.cfg_path}")
   for _ in classes.cruft_lo : print (f"cruft_lo = {_.cfg_path}")
   for _ in classes.cruft_hi : print (f"cruft_hi = {_.cfg_path}")



   filtered = Targets.filter (targets, trim)
   print (f"\nFiltered accepts {trim}")
   for target in filtered.accepts :
      print (target.cmp_name)

      
   print (f"\nFiltered rejects {trim}")      
   for target in filtered.rejects :
      print (target.cmp_name)
      
# ------------------------------------------------------------------------------
