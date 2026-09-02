// -*-Mode: C++;-*-

#ifndef __HLSBS_EXPAND_ARGS_HH__
#define __HLSBS_EXPAND_ARGS_HH__


/* ---------------------------------------------------------------------- *//*!

  \file   hlsBs/expand_args.hh
  \brief  Class to emulate the functionality of Python's argparse where
          parameters starting with '@' are treated as a file whose
          contents are lines, each containing a command line parameter.
  \author JJRussell - russell@slac.stanford.edu

  \par Description
   Any command line parameter beginning with @ is treated as (potentially)
   colon separated list of file names.

   Each line in each file contains a command line parameter \e i.e.
   --ntests=10
   --verbose
   etc.

   To ensure capability with Python's argparse rules:
     - no blank lines are allowed
     - no trailing blanks are allowed

   This allows one to capture a commonly used set of parameters in a
   named file.

  \par Example

  \code
     $ my_prgram input_file @Input_opts.txt:@Output_opts.txt
  \endcode

  \par Self test
   To test this do

   \code
      $ g++ -o test -x c++ expand_argc.hh -D SELF_TEST
   \endcode

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
 * 2026.08.25 jjr Created
\* ---------------------------------------------------------------------- */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>


/* ====================================================================== */
namespace hlsHelpers {
/* ---------------------------------------------------------------------- *//*!
 *
 * \brief Expands any indirect files containing command line parameters
 *        creating a new argc, argv set.
 *                                                                        */
/* ---------------------------------------------------------------------- */
class ExpandArgs
{
private:

   /* ------------------------------------------------------------------- *//*!
    *
    * \brief Internal struct to hold the context associated with an
    *        indirect file.
    *                                                                       */
   /* --------------------------------------------------------------------- */
   struct Ctx
   {
      FILE *m_file;  /*!< The file pointer of the indirect file             */
      int    m_cnt;  /*!< The count of command line parameters lines        */
   };
   /* --------------------------------------------------------------------  */

   /* --------------------------------------------------------------------- *//*!
    *
    * \brief Internal struct to hold which original argv where indirect
    *        files and how many comma separated files there where.
    *                                                                       */
   /* --------------------------------------------------------------------- */
   struct IdfCtx
   {
      int    m_idx;  /*!< The index of the associated argv entry            */
      int m_nfiles;  /*!< The number of files in the comma separated list   */
   };
   /* --------------------------------------------------------------------- */

public:
   /* --------------------------------------------------------------------- *//*!
    *
    * \brief Constructor to expand any and all indirect files into a new
    *        set of argc and argv's.
    *
    * \param[in] argc The original argument count
    * \param[in] argv The original argument vector
    *                                                                       */
   /* --------------------------------------------------------------------- */
   ExpandArgs (int argc, char *argv[])
   {


      // ------------------------------------------------------------------
      // Allocate enough even if every argv is an indirect file
      // The argc-1 is because the first entry argv[0] is the executable
      // file name
      // ------------------------------------------------------------------
      IdfCtx *idfCtx = (IdfCtx *)malloc ((argc-1) * sizeof (IdfCtx));

      // -----------------
      // Look for an @FILE
      // -----------------
      int nidf = 0;
      for (int idx = 1; idx < argc; idx++)
      {
         // ------------------------------------
         // If found one, catalog its argv index
         // ------------------------------------
         if (argv[idx][0] == '@')
         {
            idfCtx[nidf++].m_idx = idx;
         }
      }

      // --------------------------------------------
      // If no indirect files, just return argc, argv
      // --------------------------------------------
      if (nidf == 0)
      {
         m_argc = argc;
         m_argv = argv;
         m_free = nullptr;
         return;
      }

      // --------------------------------------
      // Count the total number of files in any
      // colon separated list
      // --------------------------------------
      int nfiles = 0;
      for (int idx = 0; idx < nidf; ++idx)
      {
         // Retrieve indirect file argument
         const char *s = argv[idfCtx[idx].m_idx];
         int         n = 1;
         while (1)
         {
            // Locate a possible colon
            const char *pos = strchr (s, ':');
            if (pos == NULL) break;

            // Does it end in a ':'
            // If so, done
            if (strlen (pos) == 1) break;

            // Advance the string past the colon
            // and count the number of files found.
            s   = pos + 1;
            n  += 1;
         }

         // Store the number of files found for this argument
         // and add on to the total number of files found.
         idfCtx[idx].m_nfiles = n;
         nfiles              += n;
      }


      // Allocate a indirect file context for each file
      Ctx  *ctx = (Ctx *)malloc (nfiles * sizeof (Ctx));

      // Count the total number of command lines in all indirect files
      int xargc = count (ctx, idfCtx, nidf, argv);

      // Allocate an array of indices marking which new argv's where found
      // This is needed to free the memory associated with them.
      m_free    = (char *)malloc ((xargc+1) * sizeof (char *));

      // The total number of arguments is
      //   - the new ones
      //   - plus the original ones
      //   - minus any of the originals that where indirect files
      m_argc    = xargc + argc - nidf;

      // Create the new list argv's
      m_argv    = fill  (ctx, idfCtx, m_argc, argc, argv, m_free);

      // Free the temporary context blocks
      free (idfCtx);
      free (ctx);

      return;
   }
   /* --------------------------------------------------------------------- */

private:
   /* --------------------------------------------------------------------- *//*!
    *
    * \brief Counts the number of extra argv's to be added
    *
    * \param[out]  ctx Maintains the count per file and the file pointer
    *                  for each indirect file
    * \param[ in]  idf Indices of the argv's that are indirect files
    * \param[ in] nidf Count of the indirect file arguments
    * \param[ in] argv The original argv's
    *                                                                       */
   /* --------------------------------------------------------------------- */
   static int count (Ctx             *ctx,
                     IdfCtx const *idfCtx,
                     int             nidf,
                     char          **argv)
   {
      int  argc = 0;
      int ifile = 0;
      for (int idx = 0; idx < nidf; idx++)
      {
         // Start the scan past the leading '@', that's the + 1
         const char *s = argv[idfCtx[idx].m_idx] + 1;

         // Loop over each file in the colon separated list
         for (int idy = 0; idy < idfCtx[idx].m_nfiles; ++idy)
         {
            // Find the end of the file name
            const char *end = strchr (s, ':');


            if   (end == NULL)
            {
               // ':' not found, 's' is the null-terminated file name
               // open it.
               FILE *fp = fopen (s, "r");
               if (fp == nullptr)
               {
                  printf ("ERROR: file not found\n"
                          "       %s\n", s);
                  exit (-1);
               }
               ctx[ifile].m_file = fopen (s, "r");
            }
            else
            {
               // ':' found, create the null-terminated file name
               // and open it
               int           len =  end - s;
               char    *filename = (char *)malloc (len + 1);
               strncpy (filename, s, len);

               filename[len]     = '\0';
               ctx[ifile].m_file = fopen (filename, "r");
               free (filename);

               s = end + 1;
            }

            // Count of how many command line parameters there are
            ctx[ifile].m_cnt  = 0;

            int    c;
            char prv = '\n';
            while ((c = fgetc(ctx[ifile].m_file)) != EOF)
            {
               // If new line, then have a command line, count it
               if (c == '\n') ctx[ifile].m_cnt++;
               prv = c;
            }

            // Count the last line if did not end with a new line
            if (prv != '\n' && prv != EOF) ctx[ifile].m_cnt++;

            // Keep track of the number of arguments to be added
            argc  += ctx[ifile].m_cnt;

            // Reposition the file reading to the beginning
            rewind (ctx[ifile].m_file);

            // Next file or done
            ifile += 1;
            if (end == NULL) break;
         }
      }

      return argc;
   }
   /* ---------------------------------------------------------------------- */

private:
   /* ---------------------------------------------------------------------- *//*!
    *
    *  \brief  Fills the expanded argv
    *  \return The filled expanded argv
    *
    *  \param[in]   ctx The context of # args in a file an its file pointer
    *  \param[in]   idf The indices of the indirect files arguments
    *  \param[in] xargc The total number of expanded argv's
    *  \param[in]  argc Original number of argv's
    *  \param[in]  argv Original argv's
    *                                                                       */
   /* --------------------------------------------------------------------- */
   static char **fill (const Ctx        *ctx,
                       const IdfCtx  *idfCtx,
                       int             xargc,
                       int              argc,
                       char           **argv,
                       char           *frees)
   {
      int     iarg  = 0;
      int      cdx  = idfCtx->m_idx;
      char **xargv  = (char **)malloc ((xargc + 1)*sizeof(char **));
      for (int idx = 0; idx < argc; idx++)
      {

         // If have an indirect file
         if (idx == cdx)
         {
            int nfiles  = idfCtx->m_nfiles;
            idfCtx     += 1;
            cdx         = idfCtx->m_idx;

            // Retrieve the command lines parameters for all the files
            for (int ifile = 0; ifile < nfiles; ++ifile)
            {
               FILE *file = ctx++->m_file;
               while (1)
               {
                  char *line = nullptr;
                  size_t len;
                  int nread = getline (&line, &len, file);

                  if (nread == EOF) break;

                  // Replace the '\n' to make it null-terminated
                  if (line[nread - 1] == '\n')
                  {
                      line[nread - 1] = '\0';
                  }

                  // Keep track of the indices or argv's that need to be freed
                  // Catalog the new argv
                  *frees++       = iarg;
                  xargv[iarg++]  = line;
               }

               fclose (file);
            }
         }
         else
         {
            // Just a regular command line parameter
            xargv[iarg++] = argv[idx];
         }
      }

      // 0 terminate the list of indices of the argvs to be freed
      // nul-terminate the argv's
      *frees      = 0;
      xargv[iarg] = nullptr;

      return xargv;
   }
   /* --------------------------------------------------------------------- */


   /* --------------------------------------------------------------------- */
public:
   ~ExpandArgs ()
    {
       auto *ptrs = m_free;

       // --------------------------
       // Check if no indirect files
       // --------------------------
       if (ptrs == nullptr) return;

       while (1)
       {
          char *ptr = ptrs++;
          if (ptr)
          {
             free ((void *)ptr);
          }
          else
          {
             break;
          }
       }

       free (m_free);
       free (m_argv);
    }

public:
   int    m_argc;
   char **m_argv;

private:
   char *m_free;
};
/* ---------------------------------------------------------------------- */
}
/* ====================================================================== */

#ifdef SELF_TEST
#include <iostream>
#include <iomanip>

int main (int argc, char const *argv[])
{
   hls_helpers::ExpandArgs args (argc, argv);


   for (int iarg = 0; iarg < args.m_argc; iarg++)
   {
      std::cout << std::setw (3) << iarg << ": "
                << args.m_argv[iarg] << std::endl;
   }

   return 0;
}
#endif

#endif
