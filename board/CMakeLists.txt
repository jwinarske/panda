cmake_minimum_required(VERSION 3.23)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build, options are: Debug, Release, or MinSizeRel." FORCE)
    message(STATUS "CMAKE_BUILD_TYPE not set, defaulting to Release.")
endif ()

project(board LANGUAGES C ASM)

set(BUILDER "DEV")
set(common_flags)

set(pedal_project_flags     -mcpu=cortex-m3 -msoft-float -DSTM32F2 -DSTM32F205xx -O2 -DPEDAL)
set(pedal_usb_project_flags -mcpu=cortex-m3 -msoft-float -DSTM32F2 -DSTM32F205xx -O2 -DPEDAL_USB)
set(panda_project_flags     -mcpu=cortex-m4 -mhard-float -DSTM32F4 -DSTM32F413xx -mfpu=fpv4-sp-d16 -fsingle-precision-constant -Os -g -DPANDA)
set(panda_h7_project_flags  -mcpu=cortex-m7 -mhard-float -DSTM32H7 -DSTM32H725xx -mfpu=fpv5-d16 -fsingle-precision-constant -Os -g -DPANDA)


if (${CMAKE_BUILD_TYPE} STREQUAL "Release")

    if (NOT DEFINED $ENV{CERT})
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

include_directories(. .. stm32fx/inc stm32h7/inc)

macro(add_project proj_name main startup_file linker_script app_start_address project_flags)

    set(flags -Wall -Wextra -Wstrict-prototypes -Werror -mlittle-endian -mthumb -nostdlib -fno-builtin -std=gnu11)

    # Bootstub
    add_executable(bootstub.${proj_name} ${startup_file} bootstub.c ../crypto/rsa.c ../crypto/sha.c)
    target_compile_options(bootstub.${proj_name} PUBLIC ${flags} ${common_flags} ${project_flags})
    target_link_libraries(bootstub.${proj_name} PUBLIC -T${linker_script} -Wl,-Map,${bootstub.${proj_name}}.map)

    add_custom_command(TARGET bootstub.${proj_name} POST_BUILD
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating Post Build Artifacts"
        # generate assembly listing
        COMMAND ${OBJDUMP} -h -S ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}.lss
        # parsing symbols with nm to generate: ${proj_name}_nm.txt
        COMMAND ${NM} --numeric-sort ${PARSE_SYMBOL_OPTIONS} ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_nm.txt
        # creating size summary table with size to generate: ${proj_name}_size.txt
        COMMAND ${SIZE} ${SIZE_OPTIONS} ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_size.txt
        # parsing symbols with readelf to generate: ${proj_name}_readelf.txt
        COMMAND ${READELF} --syms ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_readelf.txt
        # creating hex module: ${proj_name}.hex
        COMMAND ${OBJCOPY} -O ihex ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.hex
        # creating srec module: ${proj_name}.s19
        COMMAND ${OBJCOPY} -O srec --srec-forceS3 --srec-len=16 ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.s19
        # creating hex module: ${proj_name}.bin
        COMMAND ${OBJCOPY} -S -O binary ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.bin
    )

    add_custom_target(bootstub.${proj_name}.bin
        OUTPUT bootstub.${proj_name}.bin
        DEPENDS  bootstub.${proj_name}
        COMMAND ${OBJCOPY} -O binary bootstub.${proj_name} bootstub.${proj_name}.bin
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating bootstub.${proj_name}.bin"
        VERBATIM
    )

    # Build main
    add_executable(${proj_name} ${startup_file} ${main})
    target_compile_options(${proj_name} PRIVATE ${flags} ${common_flags} ${project_flags})
    target_link_libraries(${proj_name} PRIVATE -Wl,--section-start,.isr_vector={${app_start_address}} -T${linker_script} -Wl,-Map,${${proj_name}}.map)

    add_custom_command(TARGET ${proj_name} POST_BUILD
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating Post Build Artifacts"
        # generate assembly listing
        COMMAND ${OBJDUMP} -h -S ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}.lss
        # parsing symbols with nm to generate: ${proj_name}_nm.txt
        COMMAND ${NM} --numeric-sort ${PARSE_SYMBOL_OPTIONS} ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_nm.txt
        # creating size summary table with size to generate: ${proj_name}_size.txt
        COMMAND ${SIZE} ${SIZE_OPTIONS} ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_size.txt
        # parsing symbols with readelf to generate: ${proj_name}_readelf.txt
        COMMAND ${READELF} --syms ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} > ${proj_name}_readelf.txt
        # creating hex module: ${proj_name}.hex
        COMMAND ${OBJCOPY} -O ihex ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.hex
        # creating srec module: ${proj_name}.s19
        COMMAND ${OBJCOPY} -O srec --srec-forceS3 --srec-len=16 ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.s19
        # creating hex module: ${proj_name}.bin
        COMMAND ${OBJCOPY} -S -O binary ${proj_name}${CMAKE_EXECUTABLE_SUFFIX} ${proj_name}.bin
    )

    add_custom_target(${proj_name}.bin
        OUTPUT ${proj_name}.bin
        DEPENDS ${proj_name}
        COMMAND ${OBJCOPY} -O binary ${proj_name}.elf ${proj_name}.bin
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Generating ${proj_name}.bin"
        VERBATIM
    )

    # Sign main
    find_program(PYTHON python3 REQUIRED)
    set(sign_py ../crypto/sign.py)
    add_custom_command(
        OUTPUT ${proj_name}.bin.signed
        DEPENDS ${proj_name}
        COMMAND ${CMAKE_COMMAND} -E env "PYTHONPATH=rednose/helpers:selfdrive/locationd/models: SETLEN=1" ${sign_py} $SOURCE $TARGET ${cert_fn}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Signing ${proj_name}.bin"
        VERBATIM
    )
    add_custom_target(${proj_name}_bin_signed
       DEPENDS ${proj_name}.bin.signed
    )

endmacro()

if(DEFINED $ENV{PEDAL})
    message(STATUS "Building Pedal Project")
    add_project(pedal
        pedal/main.c
        stm32fx/startup_stm32f205xx.s
        stm32fx/stm32fx_flash.ld
        0x8004000
        "${pedal_project_flags}"
        )

    if (DEFINED $ENV{PEDAL_USB})
        message(STATUS "Building Pedal USB Project")
        add_project(pedal_usb
            pedal/main.c
            stm32fx/startup_stm32f205xx.s
            stm32fx/stm32fx_flash.ld
            0x8004000
            "${pedal_usb_project_flags}"
            )
    endif()
endif()
 
message(STATUS "Building Panda Project")
add_project(panda 
    main.c
    stm32fx/startup_stm32f413xx.s
    stm32fx/stm32fx_flash.ld
    0x8004000
    "${panda_project_flags}"
    )

# arm-none-eabi-gcc on comma two has no cortex-m7 support
if (NOT EXISTS "/EON")
    message(STATUS "Building Panda H7 Project")
    add_project(panda_h7
        main.c
        stm32h7/startup_stm32h7x5xx.s
        stm32h7/stm32h7x5_flash.ld
        0x8020000
        "${panda_h7_project_flags}"
        )
endif()

if (${CMAKE_BUILD_TYPE} STREQUAL "Release")

    if (NOT DEFINED $ENV{CERT})
        message(FATAL_ERROR "No certificate file specified. Please set CERT env variable")
    endif()

    set(cert_fn $ENV{CERT})
    if(NOT EXISTS ${cert_fn})
        message(FATAL_ERROR "Certificate file not found. Please specify absolute path")
    endif()

elseif(${CMAKE_BUILD_TYPE} STREQUAL "Debug")

    string(APPEND common_flags " -DDEBUG -DALLOW_DEBUG")
    set(cert_fn "${CMAKE_CURRENT_SOURCE_DIR}/../certs/debug")

else()
    message(FATAL_ERROR "Build type ${CMAKE_BUILD_TYPE} is not supported")
endif()

include_directories(
    .
    ..
    stm32fx/inc
    stm32h7/inc
    )

#def get_version(builder, build_type):
#  try:
#    git = subprocess.check_output(["git", "rev-parse", "--short=8", "HEAD"], encoding='utf8').strip()
#  except subprocess.CalledProcessError:
#    git = "unknown"
#  return f"{builder}-{git}-{build_type}"


#def to_c_uint32(x):
#  nums = []
#  for _ in range(0x20):
#    nums.append(x % (2**32))
#    x //= (2**32)
#  return "{" + 'U,'.join(map(str, nums)) + "U}"


#def get_key_header(name):
#  from Crypto.PublicKey import RSA

#  public_fn = File(f'../certs/{name}.pub').srcnode().abspath
#  rsa = RSA.importKey(open(public_fn).read())
#  assert(rsa.size_in_bits() == 1024)

#  rr = pow(2**1024, 2, rsa.n)
#  n0inv = 2**32 - pow(rsa.n, -1, 2**32)

#  r = [
#    f"RSAPublicKey {name}_rsa_key = {{",
#    f"  .len = 0x20,",
#    f"  .n0inv = {n0inv}U,",
#    f"  .n = {to_c_uint32(rsa.n)},",
#    f"  .rr = {to_c_uint32(rr)},",
#    f"  .exponent = {rsa.e},",
#    f"}};",
#  ]
#  return r

#def objcopy(source, target, env, for_signature):
#    return '$OBJCOPY -O binary %s %s' % (source[0], target[0])

# Common autogenerated includes
#with open("obj/gitversion.h", "w") as f:
#  f.write(f'const uint8_t gitversion[] = "{get_version(BUILDER, BUILD_TYPE)}";\n')

#with open("obj/version", "w") as f:
#  f.write(f'{get_version(BUILDER, BUILD_TYPE)}')

#certs = [get_key_header(n) for n in ["debug", "release"]]
#with open("obj/cert.h", "w") as f:
#  for cert in certs:
#    f.write("\n".join(cert) + "\n")
