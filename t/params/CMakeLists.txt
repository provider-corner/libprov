cmake_minimum_required(VERSION 3.0 FATAL_ERROR)
project(test_params VERSION 0.0 LANGUAGES C)
set(CMAKE_C_STANDARD 99)

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/t_params.c
                          ${CMAKE_CURRENT_SOURCE_DIR}/t_params.h
                   COMMAND perl ${CMAKE_CURRENT_SOURCE_DIR}/../../perl/gen_param_LL.pl
                           ${CMAKE_CURRENT_SOURCE_DIR}/t_params.c
                           ${CMAKE_CURRENT_SOURCE_DIR}/t_params.h
                           ${CMAKE_CURRENT_SOURCE_DIR}/test_params.dat
                   MAIN_DEPENDENCY test_params.dat
                   DEPENDS ../../perl/gen_param_LL.pl)
add_executable(test_params test_params.c t_params.c)
target_link_libraries(test_params PRIVATE libprov)
target_include_directories(test_params PRIVATE ${OPENSSL_INCLUDE_DIR})

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/t_params_speed.c
                          ${CMAKE_CURRENT_SOURCE_DIR}/t_params_speed.h
                   COMMAND perl ${CMAKE_CURRENT_SOURCE_DIR}/../../perl/gen_param_LL.pl
                           ${CMAKE_CURRENT_SOURCE_DIR}/t_params_speed.c
                           ${CMAKE_CURRENT_SOURCE_DIR}/t_params_speed.h
                           ${CMAKE_CURRENT_SOURCE_DIR}/test_params_speed.dat
                   MAIN_DEPENDENCY test_params_speed.dat
                   DEPENDS ../../perl/gen_param_LL.pl)
add_executable(test_params_speed test_params_speed.c t_params_speed.c)
target_link_libraries(test_params_speed PRIVATE libprov)
target_include_directories(test_params_speed PRIVATE ${OPENSSL_INCLUDE_DIR})

include(CTest)
add_test(NAME params COMMAND test_params)
add_test(NAME params-speed COMMAND test_params_speed)
