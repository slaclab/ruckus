
# ------------------------------------------------------------------------------
class Dictionary :
    '''
    Class following the pattern of a normal python dictionary except the value
    is a 2 element list consisting of 'type' and a 'value'. The value(s)
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
    def __init__ (self, key, tvs) :
        '''
        Constructs a class consisting of a 2 element list

        Args:
            key:   A string which will eventually become the dictionary's key
            tvs:   A 2 element list consisting of a type and one or a list of values
        '''
        self.key = key
        self.tvs = tvs
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    def __str__ (self) :
        return "key = {}\n, tvs = {}".format (self.key, self.tvs)
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Dictionary_of_Builds (Dictionary) :
    def __init__ (self, key, builds) :
        if not isinstance (builds[0], (list, tuple)) : builds = (builds,)
        super().__init__ (key, [ 'Builds', builds])
        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Dictionary_of_Files (Dictionary) :
    def __init__ (self, key, files) :
        if not isinstance (files, (list, tuple)) : files = (files,)
        super().__init__ (key, [ 'Files', files])
        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Dictionary_of_Fpgas (Dictionary) :
    def __init__ (self, key, fpgas) :
        if not isinstance (fpgas, (list,tuple)) : fpgas = (fpgas,)
        super().__init__ (key, [ 'Fpgas', fpgas])
        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Dictionary_of_Values (Dictionary) :
    def __init__ (self, key, values) :
        if not isinstance (values, (list, tuple)) : values = (values[0],)
        super().__init__ (key, [ 'Values', values])
        return
# ------------------------------------------------------------------------------
