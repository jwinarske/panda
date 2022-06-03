include_guard()

IF(NOT TRIPLE)
    set(TOOL_PREFIX "")
else()
    set(TOOL_PREFIX ${TRIPLE}-)
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
  COMMAND ${UTIL_SEARCH_CMD} ${TOOL_PREFIX}gcc
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

set(CMAKE_AR ${TOOL_PREFIX}ar)
set(CMAKE_ASM_COMPILER ${TOOL_PREFIX}gcc)
set(CMAKE_C_COMPILER ${TOOL_PREFIX}gcc)


set(CMAKE_CPPFILT ${TOOL_PREFIX}c++filt)
set(CMAKE_NM ${TOOL_PREFIX}nm)
set(CMAKE_OBJDUMP ${TOOL_PREFIX}objdump)
set(CMAKE_OBJCOPY ${TOOL_PREFIX}objcopy)
set(CMAKE_READELF ${TOOL_PREFIX}readelf)
set(CMAKE_SIZE ${TOOL_PREFIX}size)
set(CMAKE_EXECUTABLE_SUFFIX .elf)

set(GCCFLAGS
    -g
    -Wall
    -Wextra
    -pedantic
    -Wmain
    -Wundef
    -Wsign-conversion
    -Wunused-parameter
    -Wuninitialized
    -Wmissing-declarations
    -Wshadow
    -Wunreachable-code
    -Wswitch-default
    -Wswitch-enum
    -Wcast-align
    -Wmissing-include-dirs
    -Winit-self
    -Wfloat-equal
    -Wdouble-promotion
    -Wno-comment
    -gdwarf-2
    -fno-exceptions
    -ffunction-sections
    -fdata-sections
)

set(_CFLAGS ${GCCFLAGS}
    -Wunsuffixed-float-constants
    -x c
)

set(_AFLAGS ${GCCFLAGS}
    -x assembler
)

set(_LDFLAGS ${GCCFLAGS}
    -x none
    -Wl,--gc-sections
)

set(PARSE_SYMBOL_OPTIONS --print-size)

# remove list item delimeter
string(REPLACE ";" " " CMAKE_C_FLAGS "${_CFLAGS}")
string(REPLACE ";" " " CMAKE_ASM_FLAGS "${_AFLAGS}")
string(REPLACE ";" " " CMAKE_EXE_LINKER_FLAGS "${_LDFLAGS}")
