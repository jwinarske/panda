cmake_minimum_required(VERSION 3.23)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build, options are: Debug, Release, or MinSizeRel." FORCE)
    message(STATUS "CMAKE_BUILD_TYPE not set, defaulting to Release.")
endif ()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

if (NOT BUILD_NUMBER)
    set(BUILD_NUMBER 0)
endif ()

project(panda
    VERSION "1.0.${BUILD_NUMBER}"
    LANGUAGES C
    )

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(ExternalProject)
ExternalProject_Add(board_external
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/board
    UPDATE_COMMAND ""
    BUILD_IN_SOURCE 0
    CMAKE_ARGS
        -DTRIPLE=arm-none-eabi
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_STAGING_PREFIX=${CMAKE_BINARY_DIR}/out/usr
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_CURRENT_SOURCE_DIR}/cmake/gcc-toolchain.cmake
    )
add_library(board INTERFACE)
add_dependencies(board board_external)

if (BUILD_TESTING)
    add_subdirectory(tests/safety)
endif()