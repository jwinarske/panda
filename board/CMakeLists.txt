cmake_minimum_required(VERSION 3.20.5)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Choose the type of build, options are: Debug, or Release." FORCE)
    message(STATUS "CMAKE_BUILD_TYPE not set, defaulting to Debug.")
endif ()

project(board LANGUAGES C ASM)

set(CMAKE_EXECUTABLE_SUFFIX .elf)

set(pedal_project_flags     -mcpu=cortex-m3 -msoft-float -DSTM32F2 -DSTM32F205xx -O2 -DPEDAL)
set(pedal_usb_project_flags -mcpu=cortex-m3 -msoft-float -DSTM32F2 -DSTM32F205xx -O2 -DPEDAL_USB)
set(panda_project_flags     -mcpu=cortex-m4 -mhard-float -DSTM32F4 -DSTM32F413xx -Os -DPANDA -mfpu=fpv4-sp-d16 -fsingle-precision-constant -g)
set(panda_h7_project_flags  -mcpu=cortex-m7 -mhard-float -DSTM32H7 -DSTM32H725xx -Os -DPANDA -mfpu=fpv5-d16 -fsingle-precision-constant -g)

set(flags -Wall -Wextra -Wstrict-prototypes -mlittle-endian -mthumb -nostdlib -fno-builtin -std=gnu11)

macro(add_project_pedal)
    message(STATUS "Building Pedal Project")
    add_project(pedal
        pedal/main.c
        stm32fx/startup_stm32f205xx.s
        stm32fx/stm32fx_flash.ld
        0x8004000
        "${pedal_project_flags}"
    )
endmacro()
macro(add_project_pedal_usb)
    message(STATUS "Building Pedal USB Project")
    add_project(pedal_usb
        pedal/main.c
        stm32fx/startup_stm32f205xx.s
        stm32fx/stm32fx_flash.ld
        0x8004000
        "${pedal_usb_project_flags}"
        )
endmacro()
macro(add_project_panda)
    message(STATUS "Building Panda Project")
    add_project(panda
        main.c
        stm32fx/startup_stm32f413xx.s
        stm32fx/stm32fx_flash.ld
        0x8004000
        "${panda_project_flags}"
        )
endmacro()
macro(add_project_panda_h7)
    message(STATUS "Building Panda H7 Project")
    add_project(panda_h7
        main.c
        stm32h7/startup_stm32h7x5xx.s
        stm32h7/stm32h7x5_flash.ld
        0x8020000
        "${panda_h7_project_flags}"
        )
endmacro()

#
# header generation
#
find_program(GIT git REQUIRED)
execute_process(
  COMMAND ${GIT} rev-parse --short=8 HEAD
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_VERSION_SHORT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(BUILDER "DEV")
string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UC)
add_custom_target(gen_git_revision_header
    BYPRODUCTS obj/gitversion.h
    COMMAND ${CMAKE_COMMAND} -E echo "const uint8_t gitversion[] = \"${BUILDER}-${GIT_VERSION_SHORT}-${CMAKE_BUILD_TYPE_UC}\";" > obj/gitversion.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Creating gitversion.h"
    VERBATIM
    )

find_program(PYTHON3 python3 REQUIRED)
add_custom_target(gen_cert_header
    BYPRODUCTS obj/cert.h
    COMMAND ${PYTHON3} gen_cert_header.py
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Creating cert.h files"
    VERBATIM
    )

#
# cert select
#
set(common_flags)
if (${CMAKE_BUILD_TYPE} STREQUAL "Release")

    if (NOT DEFINED ENV{CERT})
        message(FATAL_ERROR "No certificate file specified. Please set CERT env variable")
    endif()

    set(cert_fn $ENV{CERT})
    if(NOT EXISTS ${cert_fn})
        message(FATAL_ERROR "Certificate file not found. Please specify absolute path")
    endif()

elseif(${CMAKE_BUILD_TYPE} STREQUAL "Debug")

    list(APPEND common_flags -DDEBUG -DALLOW_DEBUG)
    set(cert_fn "${CMAKE_CURRENT_SOURCE_DIR}/../certs/debug")

else()
    message(FATAL_ERROR "Build type ${CMAKE_BUILD_TYPE} is not supported")
endif()

#
# global includes
#
include_directories(. .. stm32fx/inc stm32h7/inc ${CMAKE_CURRENT_BINARY_DIR})

#
# project macros
#
macro(post_build proj_name)
  set(sign_py ${CMAKE_CURRENT_SOURCE_DIR}/../crypto/sign.py)
  add_custom_command(TARGET ${proj_name} POST_BUILD
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating ${proj_name} Post Build Artifacts"
        # generate assembly listing
        COMMAND ${CMAKE_OBJDUMP} -h -S ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}.lss
        # parsing symbols with nm to generate
        COMMAND ${CMAKE_NM} --numeric-sort ${PARSE_SYMBOL_OPTIONS} ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_nm.txt
        # creating size summary table with size to generate
        COMMAND ${CMAKE_SIZE} ${SIZE_OPTIONS} ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_size.txt
        # creating hex module
        COMMAND ${CMAKE_OBJCOPY} -O ihex ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.hex
        # creating srec module
        COMMAND ${CMAKE_OBJCOPY} -O srec --srec-forceS3 --srec-len=16 ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.s19
        # creating hex module
        COMMAND ${CMAKE_OBJCOPY} -S -O binary ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.bin
        # sign bin file
        COMMAND ${CMAKE_COMMAND} -E env "SETLEN=1" ${PYTHON3} ${sign_py} ${proj_name}.bin ${proj_name}.bin.signed ${cert_fn}
    )
endmacro()

set(CMAKE_EXECUTABLE_SUFFIX .elf)
macro(add_project proj_name main startup_file linker_script app_start_address project_flags)

    # Bootstub
    add_executable(bootstub.${proj_name} ${startup_file} bootstub.c ../crypto/rsa.c ../crypto/sha.c)
    target_compile_options(bootstub.${proj_name} PUBLIC ${flags} ${project_flags} ${common_flags})
    target_link_libraries(bootstub.${proj_name} PUBLIC ${flags} ${project_flags} ${common_flags}
	-T${CMAKE_CURRENT_SOURCE_DIR}/${linker_script}
	-Wl,-Map,bootstub.${proj_name}.map)
    add_dependencies(bootstub.${proj_name} gen_git_revision_header gen_cert_header)
    post_build(bootstub.${proj_name})

    # Build main
    add_executable(${proj_name} ${startup_file} ${main})
    target_compile_options(${proj_name} PRIVATE ${flags} ${project_flags} ${common_flags})
    target_link_libraries(${proj_name} PRIVATE ${flags} ${project_flags} ${common_flags}
	-Wl,--section-start,.isr_vector=${app_start_address}
	-T${CMAKE_CURRENT_SOURCE_DIR}/${linker_script}
	-Wl,-Map,${proj_name}.map)
    add_dependencies(${proj_name} gen_git_revision_header gen_cert_header)
    post_build(${proj_name})

    install(FILES
        ${CMAKE_BINARY_DIR}/${proj_name}.elf
        ${CMAKE_BINARY_DIR}/${proj_name}.lss
        ${CMAKE_BINARY_DIR}/${proj_name}_nm.txt
        ${CMAKE_BINARY_DIR}/${proj_name}_size.txt
        ${CMAKE_BINARY_DIR}/${proj_name}.hex
        ${CMAKE_BINARY_DIR}/${proj_name}.s19
        ${CMAKE_BINARY_DIR}/${proj_name}.bin
        ${CMAKE_BINARY_DIR}/${proj_name}.map
        ${CMAKE_BINARY_DIR}/${proj_name}.bin.signed
        DESTINATION bin/${proj_name})
endmacro()

#
# projects
#

if(DEFINED ENV{PEDAL})
    add_project_pedal()
    if (DEFINED ENV{PEDAL_USB})
        add_project_pedal_usb()
    endif()
endif()

add_project_panda()

# arm-none-eabi-gcc on comma two has no cortex-m7 support
if (NOT EXISTS "/EON")
    add_project_panda_h7()
endif()
