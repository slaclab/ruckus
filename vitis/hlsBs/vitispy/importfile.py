import os.path
import importlib.util
from   importlib.machinery import SourceFileLoader


# ------------------------------------------------------------------------------
# File to be imported as a module
# ------------------------------------------------------------------------------
class ImportFile :
    def __init__ (self, file) :
    
        self.file_path   = os.path.expandvars (file)
        self.module_name = os.path.splitext   (os.path.split (self.file_path)[1])[0]

        # ------------------------------------------------------
        # Manually create a custum loader for this specific file
        # This allows arbitray file extensions
        # ------------------------------------------------------
        loader    = SourceFileLoader(self.module_name, self.file_path)
    
        # Create the module spec from this loader directly
        self.spec = importlib.util.spec_from_loader(self.module_name, loader)

        return

    def add (self) :
        self.module = importlib.util.module_from_spec (self.spec)
        return

    def load (self) :
        self.spec.loader.exec_module (self.module)
# ------------------------------------------------------------------------------
