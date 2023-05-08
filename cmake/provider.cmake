#[=======================================================================[.rst:
setup_provider_openssl
----------------------

A macro that finds the OpenSSL package with the minimum version 3.0, and
applies fixups that are currently lacking in the official package.

If needed, set ``CMAKE_PREFIX_PATH`` or ``OPENSSL_ROOT_DIR`` to the
preferred OpenSSL *installation* directory.

NOTE: With MSVC, there is a problem with mixed up settings when both a custom
OpenSSL and the Shinng Light distribution are installed and accessible by CMake
at the same time.  The current workaround is to build with ``--config Release``
or anything else other than ``--config Debug``.  The ``Debug`` configuration
seems to be the default, so make sure to specify this explicitly.

build_provider
--------------

A macro that provides a fairly standard way to build a provider for OpenSSL 3.
It takes three parameters:

- the name of the provider to be built
- the cmake list of sources the provider is built from
- the cmake list of extra libraries needed when building this provider

Usage example 1 (this uses libprov functionality)::

  cmake_minimum_required(VERSION 3.12 FATAL_ERROR)
  project(
    some-provider
    VERSION 0.1
    DESCRIPTION "Some example of a provider"
    LANGUAGE C
    )
  set(CMAKE_C_STANDARD 99)

  include(libprov/cmake/provider.cmake)
  add_subdirectory(libprov)
  setup_provider_openssl()
  build_provider(some "some.c;more.c" "libprov")

Usage example 1 (a bare and entirely self contained provider)::

  cmake_minimum_required(VERSION 3.12 FATAL_ERROR)
  project(
    bare-provider
    VERSION 0.1
    DESCRIPTION "Bare minimum example of a provider"
    LANGUAGE C
    )
  set(CMAKE_C_STANDARD 99)

  include(libprov/cmake/provider.cmake)
  setup_provider_openssl()
  build_provider(some "some.c;more.c" "")

#]=======================================================================]

macro(setup_provider_openssl)
  find_package(OpenSSL 3.0 REQUIRED)

  if (NOT DEFINED OPENSSL_ROOT_DIR)
    get_filename_component(OPENSSL_ROOT_DIR ${OPENSSL_INCLUDE_DIR} DIRECTORY)
  endif()
  if (NOT DEFINED OPENSSL_PROGRAM)
    find_program(OPENSSL_PROGRAM openssl
      PATHS ${OPENSSL_ROOT_DIR} PATH_SUFFIXES apps bin NO_DEFAULT_PATH)
  endif()
  if (NOT DEFINED OPENSSL_RUNTIME_DIR)
    get_filename_component(OPENSSL_RUNTIME_DIR ${OPENSSL_PROGRAM} DIRECTORY)
  endif()
  if (NOT DEFINED OPENSSL_LIBRARY_DIR)
    get_property(_LIBPROV_property
                 TARGET OpenSSL::Crypto
                 PROPERTY IMPORTED_LOCATION)
    if (NOT _LIBPROV_property)
      # Use IMPORTED_LOCATION_RELEASE, because we know that FindOpenSSL.cmake
      # gets it right.  IMPORTED_LOCATION_DEBUG is less trustable, as it might
      # be the location of Shining Light's installation, whether this was asked
      # for or not.
      get_property(_LIBPROV_property
                   TARGET OpenSSL::Crypto
                   PROPERTY IMPORTED_LOCATION_RELEASE)
    endif()
    get_filename_component(OPENSSL_LIBRARY_DIR ${_LIBPROV_property} DIRECTORY)
    unset(_LIBPROV_property)
  endif()
  if (NOT DEFINED OPENSSL_MODULES_DIR)
    file(TO_NATIVE_PATH "${OPENSSL_PROGRAM}" _LIBPROV_program)
    if (MSVC)
      execute_process(
        COMMAND
          "${_LIBPROV_program}" info -modulesdir
        OUTPUT_VARIABLE OPENSSL_MODULES_DIR
      )
    else()
      execute_process(
        COMMAND
          ${CMAKE_COMMAND} -E env
            LD_LIBRARY_PATH=${OPENSSL_LIBRARY_DIR}
            DYLD_LIBRARY_PATH=${OPENSSL_LIBRARY_DIR}
            LIBPATH=${OPENSSL_LIBRARY_DIR}
            "${_LIBPROV_program}" info -modulesdir
        OUTPUT_VARIABLE OPENSSL_MODULES_DIR
      )
    endif()
    string(STRIP "${OPENSSL_MODULES_DIR}" OPENSSL_MODULES_DIR)
    file(TO_CMAKE_PATH "${OPENSSL_MODULES_DIR}" OPENSSL_MODULES_DIR)
    unset(_LIBPROV_program)
  endif()
  if (NOT DEFINED OPENSSL_APPLINK_SOURCE)
    # OPENSSL_APPLINK_SOURCE may be undefined, probably because of a version
    # checking bug in FindOpenSSL.cmake that exists up until cmake version
    # 3.23.0.  This does the exact same thing that FindOpenSSL.cmake is
    # supposed to do.
    find_file(OPENSSL_APPLINK_SOURCE
      NAMES openssl/applink.c
      PATHS ${OPENSSL_INCLUDE_DIR}
      NO_DEFAULT_PATH)
    if (NOT TARGET OpenSSL::applink)
      add_library(OpenSSL::applink INTERFACE IMPORTED)
      set_property(TARGET OpenSSL::applink APPEND
        PROPERTY INTERFACE_SOURCES ${OPENSSL_APPLINK_SOURCE})
    endif()
  endif()
  # Currently, knowing the exact shared library names is mostly useful for
  # Windows builds, so that's what we're going for.
  if ((NOT OPENSSL_USE_STATIC_LIBS) AND WIN32)
    if (DEFINED CMAKE_GENERATOR_PLATFORM)
      set(_LIBPROV_platform ${CMAKE_GENERATOR_PLATFORM})
    elseif (defined CMAKE_VS_PLATFORM_NAME_DEFAULT)
      set(_LIBPROV_platform ${CMAKE_VS_PLATFORM_NAME_DEFAULT})
    else()
      set(_LIBPROV_platform "Win32")
    endif()
    # Massage the platform to get the form OpenSSL uses:
    # "Win32"     -> ""         (yup, nothing!)
    # "x64"       -> "-x64"
    # "Itanium"   -> "-ia64"
    if (_LIBPROV_platform STREQUAL "Win32")
      set(_LIBPROV_platform "")
    elseif (_LIBPROV_platform STREQUAL "x64")
      set(_LIBPROV_platform "-x64")
    elseif (_LIBPROV_platform STREQUAL "Itanium")
      set(_LIBPROV_platform "-ia64")
    else()
      message(FAILURE, "Unsupported platform: ${_LIBPROV_platform}")
    endif()
    set(OPENSSL_LIBCRYPTO_SHARED
      "${OPENSSL_RUNTIME_DIR}/libcrypto-${OPENSSL_VERSION_MAJOR}${_LIBPROV_platform}.dll")
    set(OPENSSL_LIBSSL_SHARED
      "${OPENSSL_RUNTIME_DIR}/libssl-${OPENSSL_VERSION_MAJOR}${_LIBPROV_platform}.dll")
    unset(_LIBPROV_platform)
  endif()

  # This is set by the user, or above, or possibly by OpenSSLConfig.cmake
  MESSAGE(DEBUG "OPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}")
  MESSAGE(DEBUG "OPENSSL_USE_STATIC_LIBS=${OPENSSL_USE_STATIC_LIBS}")
  MESSAGE(DEBUG "OPENSSL_MSVC_STATIC_RT=${OPENSSL_MSVC_STATIC_RT}")

  # These are set by find_package()
  MESSAGE(DEBUG "OpenSSL_FOUND=${OpenSSL_FOUND}")
  MESSAGE(DEBUG "OpenSSL_CONFIG=${OpenSSL_CONFIG}")
  MESSAGE(DEBUG "OpenSSL_VERSION=${OpenSSL_VERSION}")
  MESSAGE(DEBUG "OpenSSL_VERSION_COUNT=${OpenSSL_VERSION_COUNT}")
  MESSAGE(DEBUG "OpenSSL_VERSION_MAJOR=${OpenSSL_VERSION_MAJOR}")
  MESSAGE(DEBUG "OpenSSL_VERSION_MINOR=${OpenSSL_VERSION_MINOR}")
  MESSAGE(DEBUG "OpenSSL_VERSION_PATCH=${OpenSSL_VERSION_PATCH}")
  MESSAGE(DEBUG "OpenSSL_VERSION_TWEAK=${OpenSSL_VERSION_TWEAK}")

  # These are set by FindOpenSSL.cmake
  MESSAGE(DEBUG "OPENSSL_FOUND=${OpenSSL_FOUND}")
  MESSAGE(DEBUG "OPENSSL_VERSION=${OPENSSL_VERSION}")
  MESSAGE(DEBUG "OPENSSL_VERSION_MAJOR=${OPENSSL_VERSION_MAJOR}")
  MESSAGE(DEBUG "OPENSSL_VERSION_MINOR=${OPENSSL_VERSION_MINOR}")
  MESSAGE(DEBUG "OPENSSL_VERSION_FIX=${OPENSSL_VERSION_FIX}")

  # These are set by FindOpenSSL.cmake or OpenSSLConfig.cmake, or here
  MESSAGE(DEBUG "OPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR}")
  MESSAGE(DEBUG "OPENSSL_LIBRARY_DIR=${OPENSSL_LIBRARY_DIR}")
  MESSAGE(DEBUG "OPENSSL_ENGINES_DIR=${OPENSSL_ENGINES_DIR}")
  MESSAGE(DEBUG "OPENSSL_MODULES_DIR=${OPENSSL_MODULES_DIR}")
  MESSAGE(DEBUG "OPENSSL_RUNTIME_DIR=${OPENSSL_RUNTIME_DIR}")
  MESSAGE(DEBUG "OPENSSL_APPLINK_SOURCE=${OPENSSL_APPLINK_SOURCE}")
  MESSAGE(DEBUG "OPENSSL_PROGRAM=${OPENSSL_PROGRAM}")
  MESSAGE(DEBUG "OPENSSL_LIBCRYPTO_SHARED=${OPENSSL_LIBCRYPTO_SHARED}")
  MESSAGE(DEBUG "OPENSSL_LIBSSL_SHARED=${OPENSSL_LIBSSL_SHARED}")
  MESSAGE(DEBUG "OPENSSL_CRYPTO_LIBRARY=${OPENSSL_CRYPTO_LIBRARY}")
  MESSAGE(DEBUG "OPENSSL_CRYPTO_LIBRARIES=${OPENSSL_CRYPTO_LIBRARIES}")
  MESSAGE(DEBUG "OPENSSL_SSL_LIBRARY=${OPENSSL_SSL_LIBRARY}")
  MESSAGE(DEBUG "OPENSSL_SSL_LIBRARIES=${OPENSSL_SSL_LIBRARIES}")
  MESSAGE(DEBUG "OPENSSL_LIBRARIES=${OPENSSL_LIBRARIES}")
endmacro()

macro(build_provider provider sources libraries)
  # Putting together the provider module
  add_library(${provider} MODULE ${sources})
  set_target_properties(${provider} PROPERTIES
    PREFIX "" OUTPUT_NAME "${provider}" SUFFIX ${CMAKE_SHARED_LIBRARY_SUFFIX})
  target_compile_definitions(${provider} PRIVATE
    VERSION="${CMAKE_PROJECT_VERSION}"
    BUILDTYPE="${CMAKE_BUILD_TYPE}"
    )
  target_include_directories(${provider} PRIVATE ${OPENSSL_INCLUDE_DIR})
  target_link_libraries(${provider} PRIVATE ${libraries})
endmacro()
