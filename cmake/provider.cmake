#[=======================================================================[.rst:
setup_provider_openssl
----------------------

A macro that finds the OpenSSL package with the minimum version 3.0, and
applies fixups that are currently lacking in the official package.

If needed, set ``CMAKE_PREFIX_PATH`` or ``OPENSSL_ROOT_DIR`` to the
preferred OpenSSL *installation* directory.

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
  find_program(OPENSSL_PROGRAM openssl
    PATHS ${OPENSSL_ROOT_DIR} PATH_SUFFIXES apps bin NO_DEFAULT_PATH)
  message(STATUS "Found OpenSSL application: ${OPENSSL_PROGRAM}")

  MESSAGE(DEBUG "OPENSSL_FOUND=${OPENSSL_FOUND}")
  MESSAGE(DEBUG "OPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR}")
  MESSAGE(DEBUG "OPENSSL_CRYPTO_LIBRARY=${OPENSSL_CRYPTO_LIBRARY}")
  MESSAGE(DEBUG "OPENSSL_CRYPTO_LIBRARIES=${OPENSSL_CRYPTO_LIBRARIES}")
  MESSAGE(DEBUG "OPENSSL_SSL_LIBRARY=${OPENSSL_SSL_LIBRARY}")
  MESSAGE(DEBUG "OPENSSL_SSL_LIBRARIES=${OPENSSL_SSL_LIBRARIES}")
  MESSAGE(DEBUG "OPENSSL_LIBRARIES=${OPENSSL_LIBRARIES}")
  MESSAGE(DEBUG "OPENSSL_VERSION_MAJOR=${OPENSSL_VERSION_MAJOR}")
  MESSAGE(DEBUG "OPENSSL_VERSION_MINOR=${OPENSSL_VERSION_MINOR}")
  MESSAGE(DEBUG "OPENSSL_VERSION_FIX=${OPENSSL_VERSION_FIX}")
  MESSAGE(DEBUG "OPENSSL_VERSION=${OPENSSL_VERSION}")
  MESSAGE(DEBUG "OPENSSL_APPLINK_SOURCE=${OPENSSL_APPLINK_SOURCE}")
  MESSAGE(DEBUG "OPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}")
  MESSAGE(DEBUG "OPENSSL_USE_STATIC_LIBS=${OPENSSL_USE_STATIC_LIBS}")
  MESSAGE(DEBUG "OPENSSL_MSVC_STATIC_RT=${OPENSSL_MSVC_STATIC_RT}")

  if (MSVC)
    # FindOpenSSL.cmake assumes http://www.slproweb.com/products/Win32OpenSSL.html
    # and gets it quite wrong when an install from OpenSSL source is present
    if (NOT EXISTS ${OPENSSL_CRYPTO_LIBRARY})
      set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_ROOT_DIR}/lib/libcrypto.lib)
      message(STATUS "Modified OPENSSL_CRYPTO_LIBRARY = ${OPENSSL_CRYPTO_LIBRARY}")
      set(OPENSSL_CRYPTO_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY})
      message(STATUS "Modified OPENSSL_CRYPTO_LIBRARIES = ${OPENSSL_CRYPTO_LIBRARIES}")
    endif()
    if (NOT EXISTS ${OPENSSL_SSL_LIBRARY})
      set(OPENSSL_SSL_LIBRARY ${OPENSSL_ROOT_DIR}/lib/libssl.lib)
      message(STATUS "Modified OPENSSL_SSL_LIBRARY = ${OPENSSL_SSL_LIBRARY}")
      set(OPENSSL_SSL_LIBRARIES
        ${OPENSSL_SSL_LIBRARY} ${OPENSSL_CRYPTO_LIBRARIES})
      message(STATUS "Modified OPENSSL_SSL_LIBRARIES = ${OPENSSL_CRYPTO_LIBRARIES}")
    endif()

    # FindOpenSSL.cmake makes no attempt at all to find the OpenSSL DLLs.
    if (DEFINED CMAKE_GENERATOR_PLATFORM)
      set(platform ${CMAKE_GENERATOR_PLATFORM})
    elseif (defined CMAKE_VS_PLATFORM_NAME_DEFAULT)
      set(platform ${CMAKE_VS_PLATFORM_NAME_DEFAULT})
    else()
      set(platform "Win32")
    endif()
    # Massage the platform to get the form OpenSSL uses:
    # "Win32"     -> ""         (yup, nothing!)
    # "x64"       -> "-x64"
    # "Itanium"   -> "-ia64"
    if (platform STREQUAL "Win32")
      set(platform "")
    elseif (platform STREQUAL "x64")
      set(platform "-x64")
    elseif (platform STREQUAL "Itanium")
      set(platform "-ia64")
    else()
      message(FAILURE, "Unsupported platform: ${platform}")
    endif()
    set(OPENSSL_CRYPTO_DLL_NAME
      "libcrypto-${OPENSSL_VERSION_MAJOR}${platform}")
    set(OPENSSL_SSL_DLL_NAME
      "libssl-${OPENSSL_VERSION_MAJOR}${platform}")
    MESSAGE(DEBUG "OPENSSL_CRYPTO_DLL_NAME=${OPENSSL_CRYPTO_DLL_NAME}")
    MESSAGE(DEBUG "OPENSSL_SSL_DLL_NAME=${OPENSSL_SSL_DLL_NAME}")
    find_file(OPENSSL_CRYPTO_DLL
      NAMES "${OPENSSL_CRYPTO_DLL_NAME}.dll"
      PATHS "${OPENSSL_ROOT_DIR}"
      PATH_SUFFIXES "bin")
    find_file(OPENSSL_SSL_DLL
      NAMES "${OPENSSL_SSL_DLL_NAME}.dll"
      PATHS "${OPENSSL_ROOT_DIR}"
      PATH_SUFFIXES "bin")
    MESSAGE(DEBUG "OPENSSL_CRYPTO_DLL=${OPENSSL_CRYPTO_DLL}")
    MESSAGE(DEBUG "OPENSSL_SSL_DLL=${OPENSSL_SSL_DLL}")
    if (EXISTS ${OPENSSL_CRYPTO_DLL})
      message(STATUS "Set OPENSSL_CRYPTO_DLL: ${OPENSSL_CRYPTO_DLL}")
    endif()
    if (EXISTS ${OPENSSL_SSL_DLL})
      message(STATUS "Set OPENSSL_SSL_DLL ${OPENSSL_SSL_DLL}")
    endif()

    # If OpenSSL::Crypto and OpenSSL::SSL were defined as SHARED
    # libraries when they are, in fact, shared libraries, we could
    # adjust IMPORTED_IMPLIB and IMPORTED_LOCATION to specify the DLL
    # alongside the import library.
    # Alas, that is not the case...  they are defined with the type
    # UNKNOWN, which means that they must be copied manually alongside
    # any program that's linked with them.  That needs to be done by
    # the caller.

    if (NOT DEFINED OPENSSL_APPLINK_SOURCE)
      # OPENSSL_APPLINK_SOURCE is undefined, probably because of a version
      # checking bug in FindOpenSSL.cmake that exists up until cmake version
      # 3.23.0.  This does the exact same thing that FindOpenSSL.cmake is
      # supposed to do.
      find_file(OPENSSL_APPLINK_SOURCE
        NAMES openssl/applink.c
        PATHS ${OPENSSL_INCLUDE_DIR}
        NO_DEFAULT_PATH)
      if(NOT TARGET OpenSSL::applink)
        add_library(OpenSSL::applink INTERFACE IMPORTED)
        set_property(TARGET OpenSSL::applink APPEND
          PROPERTY INTERFACE_SOURCES ${OPENSSL_APPLINK_SOURCE})
      endif()
      message(STATUS "Modified OPENSSL_APPLINK_SOURCE = ${OPENSSL_APPLINK_SOURCE}")
    endif()
  endif()
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
