cmake_minimum_required(VERSION 3.0 FATAL_ERROR)
project(libprov LANGUAGES C)
set(CMAKE_C_STANDARD 99)

find_package(OpenSSL 3.0 REQUIRED)

add_library(prov STATIC err.c)
target_include_directories(prov PUBLIC include)
target_include_directories(prov PRIVATE ${OPENSSL_INCLUDE_DIR})
