cmake_minimum_required(VERSION 3.0 FATAL_ERROR)
cmake_policy(SET
  # This allows setting C_VISIBILITY_PRESET on static libraries, for
  # those who want to do this with the libprov library
  CMP0063 NEW
)
project(libprov LANGUAGES C)
set(CMAKE_C_STANDARD 99)

if (NOT OPENSSL_FOUND)
  find_package(OpenSSL 3.0 REQUIRED)
endif()

add_library(libprov STATIC err.c num.c)
set_target_properties(libprov PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  OUTPUT_NAME "prov")
target_include_directories(libprov PUBLIC include)
target_include_directories(libprov PRIVATE ${OPENSSL_INCLUDE_DIR})
