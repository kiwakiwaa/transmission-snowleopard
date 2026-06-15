# This file Copyright (c) Transmission authors and contributors.
# It may be used under the MIT (SPDX: MIT) license.
# License text can be found in the licenses/ folder.

set(CMAKE_SYSTEM_NAME Darwin)

if(NOT TR_MACOS_DEPLOYMENT_TARGET)
    if(CMAKE_OSX_DEPLOYMENT_TARGET)
        set(TR_MACOS_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    else()
        set(TR_MACOS_DEPLOYMENT_TARGET 10.8)
    endif()
endif()

set(TR_MACOS_DEPLOYMENT_TARGET "${TR_MACOS_DEPLOYMENT_TARGET}"
    CACHE STRING "Minimum macOS version to target for deployment")
set(CMAKE_OSX_DEPLOYMENT_TARGET "${TR_MACOS_DEPLOYMENT_TARGET}"
    CACHE STRING "Minimum macOS version to target for deployment" FORCE)

if(NOT TR_MACOS_SDK_VERSION)
    set(TR_MACOS_SDK_VERSION "${TR_MACOS_DEPLOYMENT_TARGET}")
endif()
set(TR_MACOS_SDK_VERSION "${TR_MACOS_SDK_VERSION}"
    CACHE STRING "macOS SDK version to prefer for this compatibility build")

if(NOT CMAKE_OSX_SYSROOT AND DEFINED ENV{CMAKE_OSX_SYSROOT})
    file(TO_CMAKE_PATH "$ENV{CMAKE_OSX_SYSROOT}" CMAKE_OSX_SYSROOT)
endif()

if(NOT CMAKE_OSX_SYSROOT)
    foreach(_tr_macos_sdk_dir
            "/Developer/SDKs/MacOSX${TR_MACOS_SDK_VERSION}.sdk"
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${TR_MACOS_SDK_VERSION}.sdk")
        if(EXISTS "${_tr_macos_sdk_dir}")
            set(CMAKE_OSX_SYSROOT "${_tr_macos_sdk_dir}"
                CACHE PATH "macOS SDK to use for this build")
            break()
        endif()
    endforeach()
endif()

set(_tr_macos_tool_paths)
if(NOT CMAKE_PREFIX_PATH AND EXISTS "/opt/local")
    list(APPEND CMAKE_PREFIX_PATH "/opt/local")
endif()

foreach(_tr_macos_prefix IN LISTS CMAKE_PREFIX_PATH)
    list(APPEND _tr_macos_tool_paths "${_tr_macos_prefix}/bin")
endforeach()

if(DEFINED ENV{DEVELOPER_DIR})
    file(TO_CMAKE_PATH "$ENV{DEVELOPER_DIR}" _tr_macos_developer_dir)
    if(EXISTS "${_tr_macos_developer_dir}/usr/bin")
        list(APPEND _tr_macos_tool_paths "${_tr_macos_developer_dir}/usr/bin")
    endif()
    if(EXISTS "${_tr_macos_developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin")
        list(APPEND _tr_macos_tool_paths "${_tr_macos_developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin")
    endif()
endif()

if(EXISTS "/Applications/Xcode.app/Contents/Developer/usr/bin")
    list(APPEND _tr_macos_tool_paths "/Applications/Xcode.app/Contents/Developer/usr/bin")
endif()
if(EXISTS "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin")
    list(APPEND _tr_macos_tool_paths "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin")
endif()

if(EXISTS "/Developer/usr/bin")
    list(APPEND _tr_macos_tool_paths "/Developer/usr/bin")
endif()
if(EXISTS "/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin")
    list(APPEND _tr_macos_tool_paths "/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin")
endif()

if(_tr_macos_tool_paths)
    list(REMOVE_DUPLICATES _tr_macos_tool_paths)
    list(APPEND CMAKE_PROGRAM_PATH ${_tr_macos_tool_paths})
    list(REMOVE_DUPLICATES CMAKE_PROGRAM_PATH)
    set(CMAKE_PROGRAM_PATH "${CMAKE_PROGRAM_PATH}"
        CACHE STRING "Program search paths for the macOS compatibility build")
endif()

if(CMAKE_PREFIX_PATH)
    set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}"
        CACHE STRING "Installation prefixes for dependency lookup")
endif()

if(NOT CMAKE_C_COMPILER)
    find_program(TR_MACOS_C_COMPILER
        NAMES clang-mp-16 clang
        PATHS ${_tr_macos_tool_paths})

    if(TR_MACOS_C_COMPILER)
        set(CMAKE_C_COMPILER "${TR_MACOS_C_COMPILER}"
            CACHE FILEPATH "C compiler for the macOS compatibility build" FORCE)
    endif()
endif()

if(NOT CMAKE_CXX_COMPILER)
    find_program(TR_MACOS_CXX_COMPILER
        NAMES clang++-mp-16 clang++
        PATHS ${_tr_macos_tool_paths})

    if(TR_MACOS_CXX_COMPILER)
        set(CMAKE_CXX_COMPILER "${TR_MACOS_CXX_COMPILER}"
            CACHE FILEPATH "C++ compiler for the macOS compatibility build" FORCE)
    endif()
endif()

if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS 10.7)
    set(_tr_macos_arclite_candidates)

    if(CMAKE_C_COMPILER MATCHES "^/Developer/usr/bin/clang")
        list(APPEND _tr_macos_arclite_candidates
            "/Developer/usr/lib/arc/libarclite_macosx.a")
    elseif(CMAKE_C_COMPILER MATCHES "^/opt/local/bin/clang.*-mp-([0-9]+)$")
        list(APPEND _tr_macos_arclite_candidates
            "/opt/local/libexec/llvm-${CMAKE_MATCH_1}/lib/arc/libarclite_macosx.a")
    elseif(CMAKE_C_COMPILER MATCHES "^/opt/local/libexec/llvm-([0-9]+)/bin/clang")
        list(APPEND _tr_macos_arclite_candidates
            "/opt/local/libexec/llvm-${CMAKE_MATCH_1}/lib/arc/libarclite_macosx.a")
    endif()

    list(APPEND _tr_macos_arclite_candidates
        "/Developer/usr/lib/arc/libarclite_macosx.a"
        "/opt/local/libexec/llvm-16/lib/arc/libarclite_macosx.a")
    list(REMOVE_DUPLICATES _tr_macos_arclite_candidates)

    set(_tr_macos_arclite_found OFF)
    foreach(_tr_macos_arclite_candidate IN LISTS _tr_macos_arclite_candidates)
        if(EXISTS "${_tr_macos_arclite_candidate}")
            set(_tr_macos_arclite_found ON)
            set(TR_MACOS_ARCLITE_LIBRARY "${_tr_macos_arclite_candidate}"
                CACHE FILEPATH "ARC-lite runtime archive for macOS 10.6 compatibility builds" FORCE)
            break()
        endif()
    endforeach()

    if(NOT _tr_macos_arclite_found)
        string(REPLACE ";" "\n  " _tr_macos_arclite_expected "${_tr_macos_arclite_candidates}")
        message(FATAL_ERROR
            "Objective-C ARC targeting Mac OS X 10.6 requires libarclite_macosx.a, "
            "but it was not found for the active compiler (${CMAKE_C_COMPILER}).\n"
            "Install the Xcode 4.6.1 Mac ARC-lite archive at one of:\n"
            "  ${_tr_macos_arclite_expected}")
    endif()
endif()

if(CMAKE_GENERATOR MATCHES "Ninja" AND NOT CMAKE_MAKE_PROGRAM)
    find_program(TR_MACOS_NINJA
        NAMES ninja
        PATHS ${_tr_macos_tool_paths})

    if(TR_MACOS_NINJA)
        set(CMAKE_MAKE_PROGRAM "${TR_MACOS_NINJA}"
            CACHE FILEPATH "Ninja executable for the macOS compatibility build" FORCE)
    endif()
endif()

if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS 10.7)
    find_program(TR_MACOS_LINKER
        NAMES ld-latest ld
        PATHS ${_tr_macos_tool_paths})

    if(TR_MACOS_LINKER)
        set(_tr_macos_linker_flag "-fuse-ld=${TR_MACOS_LINKER}")
        foreach(_tr_macos_linker_flags_var
                CMAKE_EXE_LINKER_FLAGS_INIT
                CMAKE_MODULE_LINKER_FLAGS_INIT
                CMAKE_SHARED_LINKER_FLAGS_INIT)
            string(APPEND ${_tr_macos_linker_flags_var}
                " ${_tr_macos_linker_flag}")
        endforeach()

        foreach(_tr_macos_linker_flags_var
                CMAKE_EXE_LINKER_FLAGS
                CMAKE_MODULE_LINKER_FLAGS
                CMAKE_SHARED_LINKER_FLAGS)
            if(NOT "${${_tr_macos_linker_flags_var}}" MATCHES "(^| )${_tr_macos_linker_flag}($| )")
                string(APPEND ${_tr_macos_linker_flags_var}
                    " ${_tr_macos_linker_flag}")
                set(${_tr_macos_linker_flags_var} "${${_tr_macos_linker_flags_var}}"
                    CACHE STRING "Linker flags for the macOS compatibility build" FORCE)
            endif()
        endforeach()
    endif()
endif()

foreach(_tr_macos_prefix IN LISTS CMAKE_PREFIX_PATH)
    set(_tr_macos_libcxx_dir "${_tr_macos_prefix}/libexec/llvm-16/lib/libc++")
    if(EXISTS "${_tr_macos_libcxx_dir}/libc++.dylib")
        set(_tr_macos_libcxx_link_flags "-L${_tr_macos_libcxx_dir} -Wl,-rpath,${_tr_macos_libcxx_dir}")
        foreach(_tr_macos_linker_flags_var
                CMAKE_EXE_LINKER_FLAGS_INIT
                CMAKE_MODULE_LINKER_FLAGS_INIT
                CMAKE_SHARED_LINKER_FLAGS_INIT)
            string(APPEND ${_tr_macos_linker_flags_var}
                " ${_tr_macos_libcxx_link_flags}")
        endforeach()

        foreach(_tr_macos_linker_flags_var
                CMAKE_EXE_LINKER_FLAGS
                CMAKE_MODULE_LINKER_FLAGS
                CMAKE_SHARED_LINKER_FLAGS)
            string(FIND "${${_tr_macos_linker_flags_var}}" "-L${_tr_macos_libcxx_dir}" _tr_macos_libcxx_link_flags_pos)
            if(_tr_macos_libcxx_link_flags_pos EQUAL -1)
                string(APPEND ${_tr_macos_linker_flags_var}
                    " ${_tr_macos_libcxx_link_flags}")
                set(${_tr_macos_linker_flags_var} "${${_tr_macos_linker_flags_var}}"
                    CACHE STRING "Linker flags for the macOS compatibility build" FORCE)
            endif()
        endforeach()
        break()
    endif()
endforeach()
