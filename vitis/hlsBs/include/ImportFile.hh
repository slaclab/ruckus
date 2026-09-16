#ifndef __HLSHELPERS_IMPORT_FILE_HH__
#define __HLSHELPERS_IMPORT_FILE_HH__

/* ---------------------------------------------------------------------- *//*!

  \file   hlsHelpers/ImportFile.hh
  \brief  Does the necessary C preprocessor machinations to turn an
          unquoted #define into a quoted string to be used as file name
          in an #include
  \author JJRussell - russell@slac.stanford.edu

  \par Example

  \code
     #define  MY_INCLUDE  MyInclude.hh
     #include IMPORT_FILE(MY_INCLUDE)
  \endcode

  For convenience with other #defines that needed quoting

  \code
   #define PROGRAM_VERSION V1.0.0
   static const char ProgramVersion[] = HLSHELPER_QUOTE(PROGRAM_VERSION)

  \par
   This file is part of the ML_AI software platform. It is subject to
   the license terms in the LICENSE.txt file found in the top-level
   directory of this distribution and at:

   \verbatim
     https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
   \endverbatim

\* ---------------------------------------------------------------------- */



/* ---------------------------------------------------------------------- *\
 *
 * HISTORY
 * -------
 *
 * DATE       WHO WHAT
 * ---------- --- ------------------------------------------------------
 * 2026.08.31 jjr Created
\* ---------------------------------------------------------------------- */


#define HLSHELPER_QUOTE_IT(_x) #_x
#define HLSHELPER_QUOTE(_x)    HLSHELPER_QUOTE_IT(_x)
#define IMPORT_FILE(_x)        HLSHELPER_QUOTE_IT(_x)
#endif
