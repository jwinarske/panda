include_guard()

IF(NOT TRIPLE)
    set(GCC_TOOLCHAIN_PREFIX "")
else()
    set(GCC_TOOLCHAIN_PREFIX ${TRIPLE}-)
endif()

message(STATUS "Triple ................. ${TRIPLE}")

STRING(REGEX REPLACE "^([a-zA-Z0-9]+).*" "\\1" target_arch "${TRIPLE}")
message(STATUS "Triple Arch ............ ${target_arch}")

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR ${target_arch})

if(MINGW OR CYGWIN OR WIN32)
    set(UTIL_SEARCH_CMD where)
elseif(UNIX OR APPLE)
    set(UTIL_SEARCH_CMD which)
endif()

execute_process(
  COMMAND ${UTIL_SEARCH_CMD} ${GCC_TOOLCHAIN_PREFIX}g++
  OUTPUT_VARIABLE BINUTILS_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
get_filename_component(TOOLCHAIN_PATH ${BINUTILS_PATH} DIRECTORY)

message(STATUS "Toolchain Path ......... ${TOOLCHAIN_PATH}")

set(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN_PATH})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_AR ${GCC_TOOLCHAIN_PREFIX}ar)
set(CMAKE_ASM_COMPILER ${GCC_TOOLCHAIN_PREFIX}gcc)
set(CMAKE_C_COMPILER ${GCC_TOOLCHAIN_PREFIX}gcc)

if("${GCC_TOOLCHAIN_PREFIX}" STREQUAL "x86_64-w64-mingw32" AND "${TARGET}" STREQUAL "host")
    set(CMAKE_CXX_COMPILER ${GCC_TOOLCHAIN_PREFIX}g++-posix)
else()
    set(CMAKE_CXX_COMPILER ${GCC_TOOLCHAIN_PREFIX}g++)
endif()


set(CPPFILT ${GCC_TOOLCHAIN_PREFIX}c++filt)
set(NM ${GCC_TOOLCHAIN_PREFIX}nm)
set(OBJDUMP ${GCC_TOOLCHAIN_PREFIX}objdump)
set(OBJCOPY ${GCC_TOOLCHAIN_PREFIX}objcopy)
set(READELF ${GCC_TOOLCHAIN_PREFIX}readelf)
set(SIZE ${GCC_TOOLCHAIN_PREFIX}size)
set(CMAKE_EXECUTABLE_SUFFIX .elf)

set(GCCFLAGS
#    -g
#    -Wall
#    -Wextra
#    -pedantic
#    -Wmain
#    -Wundef
#    -Wsign-conversion
#    -Wunused-parameter
#    -Wuninitialized
#    -Wmissing-declarations
#    -Wshadow
#    -Wunreachable-code
#    -Wswitch-default
#    -Wswitch-enum
#    -Wcast-align
#    -Wmissing-include-dirs
#    -Winit-self
#    -Wfloat-equal
#    -Wdouble-promotion
#    -Wno-comment
#    -gdwarf-2
#    -fno-exceptions
#    -ffunction-sections
#    -fdata-sections
)

set(_CFLAGS ${GCCFLAGS}
#    -Wunsuffixed-float-constants
    -x c
)

set(_CXXFLAGS ${GCCFLAGS}
    -x c++
    -fno-rtti
    -fno-use-cxa-atexit
    -fno-nonansi-builtins
    -fno-threadsafe-statics
    -fno-enforce-eh-specs
    -ftemplate-depth=32
    -Wzero-as-null-pointer-constant
)

set(_AFLAGS ${GCCFLAGS}
    -x assembler
)

set(_LDFLAGS ${GCCFLAGS}
    -x none
    -Wl,--gc-sections
#    -Wl,-Map,${APP}.map
)

set(PARSE_SYMBOL_OPTIONS --print-size)

# remove list item delimeter
string(REPLACE ";" " " CMAKE_C_FLAGS "${_CFLAGS}")
string(REPLACE ";" " " CMAKE_CXX_FLAGS "${_CXXFLAGS}")
string(REPLACE ";" " " CMAKE_ASM_FLAGS "${_AFLAGS}")
string(REPLACE ";" " " CMAKE_EXE_LINKER_FLAGS "${_LDFLAGS}")
