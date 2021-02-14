cmake_minimum_required(VERSION 3.0 FATAL_ERROR)
project(libprov LANGUAGES C)
set(CMAKE_C_STANDARD 99)

if (NOT OPENSSL_FOUND)
  find_package(OpenSSL 3.0 REQUIRED)
endif()

add_library(libprov STATIC err.c)
target_include_directories(libprov PUBLIC include)
target_include_directories(libprov PRIVATE ${OPENSSL_INCLUDE_DIR})
