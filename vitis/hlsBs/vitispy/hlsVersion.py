
# Cheap cover to export the XILINX VERSION to a script
import version
print ("export HLS_XILINX_VERSION=" + version.Version.version)
