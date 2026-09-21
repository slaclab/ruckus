#ifndef __HLSHELPERS_EXPAND_ENVS_HH__
#define __HLSHELPERS_EXPAND_ENVS_HH__

/* ---------------------------------------------------------------------- *//*!

  \file   hlsHelpers/ExpandEnv.hh
  \brief  Expands the encoded environmental variable(s) expressed as
          %variable% to its shell value.
  \author JJRussell - russell@slac.stanford.edu

  \par Example

  \code
     std::string value = hlsHelpers::expand_envs ("%MY_ENV_VAL%")
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
 * 2026.08.31 jjr Created
\* ---------------------------------------------------------------------- */

#include <string>
#include <regex>

/* ====================================================================== */
namespace hlsHelpers {
/* ---------------------------------------------------------------------- *//*!
 *
 *  \brief  Finds all instances of \e xxx in \a text with patterns of the
 *          form "%xxx%" with the its environment variable
 *  \return The patched string.  This string is dynamically allocated
 *          so must be 'freed'
 *
 * \param[in] text:  The string to scan for the replacement patterns
 *
 * \par    Why is the POS necessary
 *  In general HLS GUI/IDE does not permit environment variables in
 *  the .cfg files.  There are places where it does not flag this as
 *  unallowed, but in moving the string to the shell, it mucks with
 *  the environment variable syntax, (curiously in different ways for
 *  the RUN and DEBUG launches.
 *
 *  So the above fact, combined with the syntax ${xxx} is ambigious with
 *  the Python "f" string substitution led to the workaround/kludge.
 *  Not proud of it.
 *
 *  In this context, it is used exclusively on the input, constants and
 *  golden file path names.  This allows the position of this to be
 *  determined at run-time by the user assigning the environment variable.
 *                                                                        */
/* ---------------------------------------------------------------------- */
inline std::string expand_envs (std::string text)
{
   std::string expanded (text);
   static const std::regex env_re{R"--(%([^}]+)%)--"};
   std::smatch match;

   int nerrs = 0;
   while (std::regex_search(expanded, match, env_re))
   {
      auto const  from     = match[0];
      auto const &var_str  = match[1].str();
      auto const *var_name = var_str.c_str ();
      auto const *var_exp  = std::getenv (var_name);

      if (var_exp == nullptr)
      {
         std::cerr << "ERROR: Environment variable <"
                   << var_name << "> not set" << std::endl;

         nerrs   +=   1;
         var_exp  = "";
      }

      expanded.replace(from.first, from.second, var_exp);
   }

   if (nerrs)
   {
      exit (-1);
   }

   return expanded;
}
/* ---------------------------------------------------------------------- */
}
/* ====================================================================== */

#endif
