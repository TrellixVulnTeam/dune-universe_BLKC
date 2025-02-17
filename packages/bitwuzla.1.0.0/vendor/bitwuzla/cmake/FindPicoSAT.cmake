###
# Bitwuzla: Satisfiability Modulo Theories (SMT) solver.
#
# This file is part of Bitwuzla.
#
# Copyright (C) 2007-2021 by the authors listed in the AUTHORS file.
#
# See COPYING for more information on using this software.
##
# Find PicoSAT
# PicoSAT_FOUND - found PicoSAT lib
# PicoSAT_INCLUDE_DIR - the PicoSAT include directory
# PicoSAT_LIBRARIES - Libraries needed to use PicoSAT

find_path(PicoSAT_INCLUDE_DIR NAMES picosat.h)
find_library(PicoSAT_LIBRARIES NAMES picosat)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PicoSAT
  DEFAULT_MSG PicoSAT_INCLUDE_DIR PicoSAT_LIBRARIES)

mark_as_advanced(PicoSAT_INCLUDE_DIR PicoSAT_LIBRARIES)
if(PicoSAT_LIBRARIES)
  message(STATUS "Found PicoSAT library: ${PicoSAT_LIBRARIES}")
endif()
