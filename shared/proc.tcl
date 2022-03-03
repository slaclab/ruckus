##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## Custom TLC source function
proc SourceTclFile { filePath } {
   if { [file exists ${filePath}] == 1 } {
      source ${filePath}
      return true;
   } else {
      return false;
   }
}

## Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}

## Function for putting the TCL script into a wait (in units of seconds)
proc sleep {N} {
   after [expr {int($N * 1000)}]
}

## Function for comparing two list
proc ListComp { List1 List2 } {
   # Refer to https://wiki.tcl.tk/15489 under "[tcl_hack] - 2015-08-14 13:52:07"
   set DiffList {}
   foreach Item $List1 {
      if { [ lsearch -exact $List2 $Item ] == -1 } {
         lappend DiffList $Item
      }
   }
   foreach Item $List2 {
      if { [ lsearch -exact $List1 $Item ] == -1 } {
         if { [ lsearch -exact $DiffList $Item ] == -1 } {
            lappend DiffList $Item
         }
      }
   }
   return $DiffList
}

proc ::findFiles { baseDir pattern } {
   set dirs [ glob -nocomplain -type d [ file join $baseDir * ] ]
   set files {}
   foreach dir $dirs {
      lappend files {*}[ findFiles $dir $pattern ]
   }
   lappend files {*}[ glob -nocomplain -type f [ file join $baseDir $pattern ] ]
   return $files
}

## Build INFO
proc BuildInfo { } {
   exec rm -f $::env(PROJ_DIR)/build.info
   set fp [open "$::env(PROJ_DIR)/build.info" w+]
   puts $fp "PROJECT: $::env(PROJECT)"
   puts $fp "FW_VERSION: $::env(PRJ_VERSION)"
   puts $fp "BUILD_STRING: $::env(BUILD_STRING)"
   puts $fp "GIT_HASH: $::env(GIT_HASH_LONG)"
   close $fp
}

## Check if you have write permission
proc CheckWritePermission { } {
   set src_rc [catch {exec touch $::env(MODULES)/ruckus/LICENSE.txt}]
   if {$src_rc} {
      puts "\n\n\n\n\n********************************************************"
      puts "********************************************************"
      puts "********************************************************"
      puts "Unable to touch $::env(MODULES)/ruckus/LICENSE.txt"
      puts "Please verify that your Unix session has not expired"
      puts "********************************************************"
      puts "********************************************************"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
}

## Compares the tag release to a user defined value
proc CompareTags { tag lockTag } {

   # Blowoff everything except for the major, minor, and patch numbers
   scan $tag     "%d.%d.%d" major minor patch
   scan $lockTag "%d.%d.%d" majorLock minorLock patchLock

   ###################################################################
   # Major Number Checking
   ###################################################################
   # major.X.X < majorLock.X.X
   if { [expr { ${major} < ${majorLock} }] } {
      set validTag 0
   # major.X.X = majorLock.X.X
   } elseif { [expr { ${major} == ${majorLock} }] } {
      ################################################################
      # Minor Number Checking
      ################################################################
      # major.minor.X < major.minorLock.X
      if { [expr { ${minor} < ${minorLock} }] } {
         set validTag 0
      # major.minor.X = major.minorLock.X
      } elseif { [expr { ${minor} == ${minorLock} }] } {
         #############################################################
         # Patch Number Checking
         #############################################################
         # major.minor.patch < major.minor.patchLock
         if { [expr { ${patch} < ${patchLock} }] } {
            set validTag 0
         # major.minor.patch = major.minor.patchLock
         } elseif { [expr { ${patch} == ${patchLock} }] } {
            set validTag 1
         # major.minor.patch > major.minor.patchLock
         } else {
            set validTag 1
         }
      ################################################################
      # major.minor.X > major.minorLock.X
      } else {
         set validTag 1
      }
   ###################################################################
   # major.X.X > majorLock.X.X
   } else {
      set validTag 1
   }

   return ${validTag}
}

## Check the git and git-lfs versions
proc CheckGitVersion { } {
   ######################################
   # Define the git/git-lfs version locks
   ######################################
   set gitLockTag    {2.9.0}
   set gitLfsLockTag {2.1.1}
   ######################################

   # Get the git version
   set gitStr [exec git version]
   scan $gitStr "%s %s %s" name temp gitTag

   # Get the git-lfs version
   set gitStr [exec git-lfs version]
   scan $gitStr "git-lfs/%s %s" gitLfsTag temp

   # Compare the tags
   set validGitTag    [CompareTags ${gitTag}    ${gitLockTag}]
   set validGitLfsTag [CompareTags ${gitLfsTag} ${gitLfsLockTag}]

   # Check the validGitTag flag
   if { ${validGitTag} == 0 } {
      puts "\n\n*********************************************************"
      puts "Your git version = v${gitTag}"
      puts "However, ruckus git version Lock = v${gitLockTag}"
      puts "Please update this git version v${gitLockTag} (or later)"
      puts "*********************************************************\n\n"
      exit -1
   }

   # Check the validGitLfsTag flag
   if { ${validGitLfsTag} == 0 } {
      puts "\n\n*********************************************************"
      puts "Your git-lfs version = v${gitLfsTag}"
      puts "However, ruckus git-lfs version Lock = v${gitLfsLockTag}"
      puts "Please update this git-lfs version v${gitLfsLockTag} (or later)"
      puts "*********************************************************\n\n"
      exit -1
   }
}

## Checks the submodule tag release to a user defined value
proc SubmoduleCheck { name lockTag  {mustBeExact ""} } {

   # Get the submodule status string
   set retVar [catch {set submodule [exec git -C $::env(MODULES) submodule status -- ${name}]} _RESULT]
   if {$retVar} {
      puts "\n\n\n\n\n********************************************************"
      puts "SubmoduleCheck(name=$name): ${_RESULT}"
      puts "********************************************************\n\n\n\n\n"
      return -1
   }

   # Scan for the hash, name, and tag portions of the string (assumes a 'v' prefix to start with)
   if { [scan $submodule "%s %s (v%s)" hash temp tag] != 3 } {
      # Check again with 'v' prefix
      set prefix ""
      scan $submodule "%s %s (%s)" hash temp tag
   } else {
      set prefix "v"
   }
   scan $tag "%d.%d.%d%s" major minor patch d
   set tag [string map [list $d ""] $tag]
   set tag "${major}.${minor}.${patch}"
   scan $lockTag "%d.%d.%d" majorLock minorLock patchLock

   # Compare the tags
   set validTag [CompareTags ${tag} ${lockTag}]

   # Check the validTag flag
   if { ${validTag} != 1 } {
      puts "\n\n*********************************************************"
      puts "Your git clone ${name} = ${prefix}${tag}"
      puts "However, ${name} Lock  = ${prefix}${lockTag}"
      puts "Please update this submodule tag to ${prefix}${lockTag} (or later)"
      puts "*********************************************************\n\n"
      return -1
   } elseif { ${major} == ${majorLock} && ${minor} == ${minorLock} && ${patch} == ${patchLock} } {
      return 0
   } elseif { ${mustBeExact} == "mustBeExact" } {
      puts "\n\n*********************************************************"
      puts "Your git clone ${name} = ${prefix}${tag}"
      puts "However, ${name} Lock  = ${prefix}${lockTag}"
      puts "Please update this submodule tag to ${prefix}${lockTag}"
      puts "*********************************************************\n\n"
      return -1
   } else {
      return 1
   }
}

## Generate the build string
proc GenBuildString { pkgDir } {

   # Make directory if it does not exist
   exec mkdir -p ${pkgDir}

   # Generate the build string
   binary scan [encoding convertto ascii $::env(BUILD_STRING)] c* bstrAsic
   set buildString ""
   foreach decChar ${bstrAsic} {
      set hexChar [format %02X ${decChar}]
      set buildString ${buildString}${hexChar}
   }
   for {set n [string bytelength ${buildString}]} {$n < 512} {incr n} {
      set padding "0"
      set buildString ${buildString}${padding}
   }

   # Generate the Firmware Version string
   scan $::env(PRJ_VERSION) %x decVer
   set fwVersion [format %08X ${decVer}]

   # Generate the GIT SHA-1 string
   set gitHash $::env(GIT_HASH_LONG)
   while { [string bytelength $gitHash] != 40 } {
      set gitHash "0${gitHash}"
   }

   # Check for non-zero Vivado version (in-case non-Vivado project)
   if {  $::env(VIVADO_VERSION) > 0.0} {
      # Set the top-level generic values
      set buildInfo "BUILD_INFO_G=2240'h${gitHash}${fwVersion}${buildString}"
      set_property generic ${buildInfo} -objects [current_fileset]
   }

   # Auto-generate a "BUILD_INFO_C" VHDL package for applications that do NOT support top-level generic
   set out [open ${pkgDir}/BuildInfoPkg.vhd w]
   puts ${out} "library ieee;"
   puts ${out} "use ieee.std_logic_1164.all;"
   puts ${out} "library surf;"
   puts ${out} "use surf.StdRtlPkg.all;"
   puts ${out} "package BuildInfoPkg is"
   puts ${out} "constant BUILD_INFO_C : BuildInfoType :=x\"${gitHash}${fwVersion}${buildString}\";"
   puts ${out} "end BuildInfoPkg;"
   close ${out}
   loadSource -lib ruckus -path ${pkgDir}/BuildInfoPkg.vhd
}
