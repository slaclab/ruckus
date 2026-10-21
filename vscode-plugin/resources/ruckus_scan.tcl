##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
## ruckus_scan.tcl
##
## Evaluates a ruckus project's ruckus.tcl tree *without* Vivado.
## Every ruckus loader procedure (loadSource, loadConstraints, loadIpCore, ...)
## is replaced by a stub that records what would have been loaded. Results are
## written to stdout as one JSON object per line. Anything the project scripts
## print with `puts` is redirected to stderr.
##
## Usage: tclsh ruckus_scan.tcl <PROJ_DIR>
## Environment: all Makefile-derived variables (PRJ_PART, TOP_DIR, ...) are
## expected in the process environment.
##############################################################################

namespace eval ::rs {
   variable nextId 0
   variable stack {}
}

fconfigure stdout -encoding utf-8 -translation lf
fconfigure stderr -encoding utf-8

# ---------------------------------------------------------------------------
# JSON output helpers
# ---------------------------------------------------------------------------
proc ::rs::js {s} {
   set s [string map [list \\ \\\\ \" \\\" \n \\n \r \\r \t \\t] $s]
   regsub -all {[\x00-\x1f]} $s {} s
   return "\"$s\""
}

proc ::rs::emit {args} {
   set parts {}
   foreach {k v} $args {
      if {[string is integer -strict $v] && [string index $k 0] eq "#"} {
         lappend parts "[::rs::js [string range $k 1 end]]:$v"
      } else {
         lappend parts "[::rs::js $k]:[::rs::js $v]"
      }
   }
   ::rs::realputs stdout "\{[join $parts ,]\}"
   flush stdout
}

# Location (file, line) of the innermost sourced script line on the stack
proc ::rs::loc {} {
   for {set i [expr {[info frame] - 1}]} {$i > 0} {incr i -1} {
      set f [info frame $i]
      if {[dict exists $f type] && [dict get $f type] eq "source" &&
          [dict exists $f file] && [dict exists $f line]} {
         set file [file normalize [dict get $f file]]
         if {$file ne $::rs::self} {
            return [list $file [dict get $f line]]
         }
      }
   }
   return [list "" 0]
}

proc ::rs::current {} {
   if {[llength $::rs::stack] == 0} { return 0 }
   return [lindex $::rs::stack end]
}

proc ::rs::problem {msg {severity error}} {
   lassign [::rs::loc] file line
   ::rs::emit t problem #node [::rs::current] msg $msg severity $severity file $file #line $line
}

proc ::rs::norm {p} {
   if {$p eq ""} { return "" }
   return [file normalize $p]
}

# ---------------------------------------------------------------------------
# Redirect `puts` to stderr so stdout only carries JSON
# ---------------------------------------------------------------------------
rename puts ::rs::realputs
proc puts {args} {
   set nonl 0
   if {[lindex $args 0] eq "-nonewline"} {
      set nonl 1
      set args [lrange $args 1 end]
   }
   if {[llength $args] == 1} {
      set chan stderr
      set msg [lindex $args 0]
   } else {
      set chan [lindex $args 0]
      set msg [lindex $args 1]
      if {$chan eq "stdout"} { set chan stderr }
   }
   if {$nonl} {
      ::rs::realputs -nonewline $chan $msg
   } else {
      ::rs::realputs $chan $msg
   }
}

# ---------------------------------------------------------------------------
# Environment: defaults for variables the Makefile normally exports, so that
# `$::env(X)` reads in project scripts do not abort the scan.
# ---------------------------------------------------------------------------
foreach {k v} {
   VIVADO_VERSION 2024.2  RUCKUS_SIM_BACKEND xsim  PRJ_PART ""  PROJECT ""
   PRJ_VERSION 0x00000000  OVERRIDE_SUBMODULE_LOCKS 1  GIT_BYPASS 1
   REMOVE_UNUSED_CODE 0  RECONFIG_CHECKPOINT 0  RECONFIG_ENDPOINT 0
   RECONFIG_PBLOCK 0  USE_SEGMENTED_CONFIG 0  VIVADO_PROJECT_SIM ""
   VIVADO_PROJECT_SIM_TIME all  RUCKUS_QUIET_FLAG -quiet  RUCKUS_FPGA_ARCH ""
   RUCKUS_PROC_TCL ""  TOP_DIR ""  PROJ_DIR ""  OUT_DIR ""  RUCKUS_DIR ""
} {
   if {![info exists ::env($k)] || ($::env($k) eq "" && $v ne "")} { set ::env($k) $v }
}
if {$::env(TOP_DIR) ne "" && ![info exists ::env(MODULES)]} {
   set ::env(MODULES) $::env(TOP_DIR)/submodules
}

# ---------------------------------------------------------------------------
# Option parsing (subset of ::cmdline::getoptions, which may not be installed)
# spec: list of {name hasArg}
# ---------------------------------------------------------------------------
proc ::rs::opts {spec argList} {
   set res {}
   foreach s $spec {
      lassign $s name hasArg
      dict set res $name [expr {$hasArg ? "" : 0}]
   }
   set n [llength $argList]
   for {set i 0} {$i < $n} {incr i} {
      set a [lindex $argList $i]
      if {[string index $a 0] ne "-"} { continue }
      set key [string range $a 1 end]
      set found 0
      foreach s $spec {
         lassign $s name hasArg
         if {$name eq $key} {
            set found 1
            if {$hasArg} {
               incr i
               dict set res $name [lindex $argList $i]
            } else {
               dict set res $name 1
            }
         }
      }
      if {!$found} {
         ::rs::problem "unknown option '$a'" warning
      }
   }
   return $res
}

# Record files coming from a -path or -dir option.
# kind: source | constraint | ip | bd | zip | ncr
proc ::rs::collect {cmd kind o exts extra} {
   set path [dict get $o path]
   set dir  ""
   if {[dict exists $o dir]} { set dir [dict get $o dir] }
   if {$path ne "" && $dir ne ""} {
      ::rs::problem "$cmd: Cannot specify both -path and -dir"
      return
   }
   # Vivado runs in OUT_DIR, not in the source tree: a relative path that the
   # scan resolves (cwd = PROJ_DIR) aborts the real build
   foreach {opt v} [list -path $path -dir $dir] {
      if {$v ne "" && [file pathtype $v] ne "absolute"} {
         ::rs::problem "$cmd: $opt \"$v\" is relative; Vivado resolves it against OUT_DIR. Use \"\$::DIR_PATH/$v\"" warning
      }
   }
   lassign [::rs::loc] file line
   set node [::rs::current]
   if {$path ne ""} {
      set p [::rs::norm $path]
      if {![file exists $p]} {
         ::rs::problem "$cmd: $path doesn't exist"
         return
      }
      set ext [string tolower [file extension $p]]
      if {[lsearch -exact $exts $ext] < 0} {
         ::rs::problem "$cmd: $path does not have a \[[join $exts ,]\] file extension"
         return
      }
      ::rs::emit t file #node $node kind $kind path $p via path file $file #line $line {*}$extra
   } elseif {$dir ne ""} {
      set d [::rs::norm $dir]
      if {![file isdirectory $d]} {
         ::rs::problem "$cmd: $dir doesn't exist"
         return
      }
      set patterns {}
      foreach e $exts { lappend patterns "*$e" }
      set list [lsort [glob -nocomplain -types f -directory $d {*}$patterns]]
      if {[llength $list] == 0} {
         ::rs::problem "$cmd: $dir directory does not have any \[[join $exts ,]\] files"
         return
      }
      ::rs::emit t dir #node $node kind $kind path $d file $file #line $line
      foreach p $list {
         ::rs::emit t file #node $node kind $kind path [::rs::norm $p] via dir file $file #line $line {*}$extra
      }
   } else {
      ::rs::problem "$cmd: neither -path nor -dir given" warning
   }
}

# ---------------------------------------------------------------------------
# ruckus public API stubs
# ---------------------------------------------------------------------------
set ::DIR_PATH ""
set ::DIR_LIST ""
set ::IP_LIST  ""
set ::IP_FILES ""
set ::BD_FILES ""

proc loadRuckusTcl {filePath {flags ""}} {
   set filePath [::rs::norm $filePath]
   lassign [::rs::loc] file line
   set parent [::rs::current]
   set id [incr ::rs::nextId]
   if {![file exists $filePath/ruckus.tcl]} {
      ::rs::emit t problem #node $parent msg "loadRuckusTcl: $filePath/ruckus.tcl doesn't exist" severity error file $file #line $line
      return
   }
   # Guard against accidental infinite recursion
   if {[llength $::rs::stack] > 64} {
      ::rs::emit t problem #node $parent msg "loadRuckusTcl: recursion too deep at $filePath" severity error file $file #line $line
      return
   }
   ::rs::emit t enter #id $id #parent $parent dir $filePath file $file #line $line
   set LOC_PATH $::DIR_PATH
   set ::DIR_PATH $filePath
   lappend ::rs::stack $id
   set rc [catch {uplevel #0 [list ::rs::realsource $filePath/ruckus.tcl]} err opts]
   if {$rc == 1} {
      if {$err ne "__ruckus_exit__"} {
         set einfo [dict get $opts -errorinfo]
         set eline 0
         if {[regexp {\(file "[^"]*ruckus\.tcl" line (\d+)\)} $einfo -> eline]} {}
         ::rs::emit t problem #node $id msg "Tcl error: $err" severity error file $filePath/ruckus.tcl #line $eline
      }
   }
   set ::rs::stack [lrange $::rs::stack 0 end-1]
   set ::DIR_PATH $LOC_PATH
   set ::DIR_LIST "$::DIR_LIST $filePath"
   ::rs::emit t leave #id $id
}

proc loadSource {args} {
   set o [::rs::opts {{sim_only 0} {path 1} {dir 1} {lib 1} {fileType 1}} $args]
   set exts {.vhd .vhdl .v .vh .sv .svh .dat .coe .mem .edif .dcp}
   ::rs::collect loadSource source $o $exts [list lib [dict get $o lib] #sim [dict get $o sim_only] fileType [dict get $o fileType]]
}

proc loadConstraints {args} {
   set o [::rs::opts {{path 1} {dir 1}} $args]
   ::rs::collect loadConstraints constraint $o {.xdc .tcl} {}
}

proc loadIpCore {args} {
   set o [::rs::opts {{path 1} {dir 1} {doUpgrade 0} {forceImport 0}} $args]
   ::rs::collect loadIpCore ip $o {.xci .xcix} {}
}

proc loadBlockDesign {args} {
   set o [::rs::opts {{path 1} {dir 1}} $args]
   ::rs::collect loadBlockDesign bd $o {.bd .tcl} {}
}

proc loadZipIpCore {args} {
   set o [::rs::opts {{path 1} {dir 1} {repo_path 1}} $args]
   ::rs::collect loadZipIpCore zip $o {.zip} {}
}

proc loadNoCSolution {args} {
   set o [::rs::opts {{path 1}} $args]
   dict set o dir ""
   ::rs::collect loadNoCSolution ncr $o {.ncr} {}
}

# FPGA architecture derived from PRJ_PART (mimics Vivado's ARCHITECTURE)
proc getFpgaArch {} {
   if {$::env(RUCKUS_FPGA_ARCH) ne ""} { return $::env(RUCKUS_FPGA_ARCH) }
   set p [string tolower $::env(PRJ_PART)]
   if {[regexp {^xc7a} $p]} { return artix7 }
   if {[regexp {^xc7k} $p]} { return kintex7 }
   if {[regexp {^xc7v} $p]} { return virtex7 }
   if {[regexp {^xc7z} $p]} { return zynq }
   if {[regexp {^xc7s} $p]} { return spartan7 }
   if {[regexp {^xcku\d+p} $p]} { return kintexuplus }
   if {[regexp {^xcku} $p]} { return kintexu }
   if {[regexp {^xcvu(31|33|35|37|45|47|57)p} $p]} { return virtexuplusHBM }
   if {[regexp {^xcvu\d+p} $p]} { return virtexuplus }
   if {[regexp {^xcvu} $p]} { return virtexu }
   # Alveo cards (XCU50/55/280 have HBM; XCU200/250 are VU9P/VU13P)
   if {[regexp {^xcu(50|55|280)} $p]} { return virtexuplusHBM }
   if {[regexp {^xcu\d} $p]} { return virtexuplus }
   if {[regexp {^xczu\d+dr} $p]} { return zynquplusRFSOC }
   if {[regexp {^xczu} $p]} { return zynquplus }
   if {[regexp {^xcau} $p]} { return artixuplus }
   if {[regexp {^xcv[cmphe]} $p]} { return versal }
   return ""
}
proc getFpgaFamily {} { return [getFpgaArch] }
proc isVersal {} { return [expr {[getFpgaArch] eq "versal"}] }

# Version / environment checks always pass
foreach p {VersionCheck VersionRangeCheck SubmoduleCheck CheckVivadoVersion
           CheckGitVersion RogueCheckLibZmq CheckPrjConfig CheckWritePermission} {
   proc $p {args} { return 0 }
}
proc VersionCompare {args} { return 0 }
proc SourceTclFile {args} { return 0 }
proc GetCpuNumber {} { return 1 }

# ---------------------------------------------------------------------------
# Vivado command stubs that matter for the model
# ---------------------------------------------------------------------------
proc current_fileset {args} {
   if {[lsearch $args -simset] >= 0} { return sim_1 }
   if {[lsearch $args -constrset] >= 0} { return constrs_1 }
   return sources_1
}
proc get_filesets {args} {
   foreach a $args { if {[string index $a 0] ne "-"} { return $a } }
   return ""
}
proc current_project {args} { return ruckus_project }

proc set_property {args} {
   # set_property top <name> <fileset>
   set plain {}
   foreach a $args { if {[string index $a 0] ne "-"} { lappend plain $a } }
   if {[llength $plain] >= 3 && [string tolower [lindex $plain 0]] eq "top"} {
      set fs [lindex $plain 2]
      if {$fs eq ""} { set fs sources_1 }
      lassign [::rs::loc] file line
      ::rs::emit t top fileset $fs value [lindex $plain 1] file $file #line $line
   }
   return ""
}

proc add_files {args} {
   lassign [::rs::loc] file line
   set fs sources_1
   set skip 0
   for {set i 0} {$i < [llength $args]} {incr i} {
      set a [lindex $args $i]
      if {$a eq "-fileset"} { incr i; set fs [lindex $args $i]; continue }
      if {[string index $a 0] eq "-"} { continue }
      foreach f $a {
         set p [::rs::norm $f]
         if {[file isfile $p]} {
            set kind source
            set ext [string tolower [file extension $p]]
            if {$fs eq "constrs_1" || $ext eq ".xdc"} { set kind constraint }
            if {$ext eq ".xci" || $ext eq ".xcix"} { set kind ip }
            ::rs::emit t file #node [::rs::current] kind $kind path $p via add_files file $file #line $line #sim [expr {$fs eq "sim_1"}]
         }
      }
   }
   return ""
}

# A real build aborts at `exit`: report it where it was called, then stop the scan
rename exit ::rs::realexit
proc exit {args} {
   set code [expr {[llength $args] ? [lindex $args 0] : 0}]
   if {$code != 0} {
      ::rs::problem "exit $code: the build would abort here"
   } else {
      ::rs::problem "exit: the build would stop here" warning
   }
   error "__ruckus_exit__"
}
proc exec {args} { return "" }

# `source` of the ruckus proc library is a no-op; anything else is evaluated
rename source ::rs::realsource
proc source {args} {
   # The file is the last argument (source ?-encoding name? ?-notrace? ?-quiet? file)
   set f [lindex $args end]
   set opts [lrange $args 0 end-1]
   set enc [lsearch -exact $opts -encoding]
   set encArgs [expr {$enc >= 0 ? [lrange $opts $enc [expr {$enc + 1}]] : {}}]
   # Anything inside RUCKUS_DIR (vivado/proc.tcl, vivado_proc.tcl, shared/proc.tcl,
   # ...) is the real ruckus library and would overwrite the stubs above.
   set nf [file normalize $f]
   if {($::env(RUCKUS_PROC_TCL) ne "" && $nf eq [file normalize $::env(RUCKUS_PROC_TCL)]) ||
       ($::env(RUCKUS_DIR) ne "" &&
        [string first [file normalize $::env(RUCKUS_DIR)]/ $nf] == 0)} {
      return
   }
   if {![file exists $f]} {
      ::rs::problem "source: $f doesn't exist" warning
      return
   }
   uplevel 1 [list ::rs::realsource {*}$encArgs $f]
}

proc package {args} {
   # tcllib may be missing; pretend everything is available
   if {[lindex $args 0] eq "require"} { return 1.0 }
   return ""
}

# Every other unknown command (Vivado built-ins) is ignored
proc unknown {args} { return "" }

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
set ::rs::self [file normalize [info script]]
set projDir [file normalize [lindex $argv 0]]
::rs::emit t start proj $projDir arch [getFpgaArch]
loadRuckusTcl $projDir
::rs::emit t done
::rs::realexit 0
