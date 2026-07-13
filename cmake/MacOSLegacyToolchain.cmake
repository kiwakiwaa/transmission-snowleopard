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
    set(_tr_macos_sdk_names "MacOSX${TR_MACOS_SDK_VERSION}.sdk")
    if(TR_MACOS_SDK_VERSION VERSION_EQUAL 10.4)
        list(APPEND _tr_macos_sdk_names "MacOSX10.4u.sdk")
    endif()

    foreach(_tr_macos_sdk_dir
            "/Developer/SDKs"
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs")
        foreach(_tr_macos_sdk_name IN LISTS _tr_macos_sdk_names)
            if(EXISTS "${_tr_macos_sdk_dir}/${_tr_macos_sdk_name}")
                set(CMAKE_OSX_SYSROOT "${_tr_macos_sdk_dir}/${_tr_macos_sdk_name}"
                    CACHE PATH "macOS SDK to use for this build")
                break()
            endif()
        endforeach()
        if(CMAKE_OSX_SYSROOT)
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

set(TR_MACOS_LLVM_MIN_VERSION 16
    CACHE STRING "Minimum LLVM/Clang version to use for the macOS compatibility build")

set(_tr_macos_versioned_c_compiler)
set(_tr_macos_versioned_cxx_compiler)
set(_tr_macos_versioned_llvm_version)
set(_tr_macos_llvm_versions)
set(_tr_macos_cxx_compiler_provided OFF)

if(CMAKE_CXX_COMPILER)
    set(_tr_macos_cxx_compiler_provided ON)
endif()

foreach(_tr_macos_tool_path IN LISTS _tr_macos_tool_paths)
    file(GLOB _tr_macos_clang_candidates "${_tr_macos_tool_path}/clang-mp-*")
    foreach(_tr_macos_clang_candidate IN LISTS _tr_macos_clang_candidates)
        if(_tr_macos_clang_candidate MATCHES "/clang-mp-([0-9]+)$")
            set(_tr_macos_llvm_version "${CMAKE_MATCH_1}")
            if(NOT _tr_macos_llvm_version VERSION_LESS TR_MACOS_LLVM_MIN_VERSION
                    AND EXISTS "${_tr_macos_tool_path}/clang++-mp-${_tr_macos_llvm_version}")
                list(APPEND _tr_macos_llvm_versions "${_tr_macos_llvm_version}")
            endif()
        endif()
    endforeach()
endforeach()

if(_tr_macos_llvm_versions)
    list(REMOVE_DUPLICATES _tr_macos_llvm_versions)
    list(SORT _tr_macos_llvm_versions COMPARE NATURAL ORDER DESCENDING)
    list(GET _tr_macos_llvm_versions 0 _tr_macos_versioned_llvm_version)

    foreach(_tr_macos_tool_path IN LISTS _tr_macos_tool_paths)
        set(_tr_macos_c_compiler_candidate "${_tr_macos_tool_path}/clang-mp-${_tr_macos_versioned_llvm_version}")
        set(_tr_macos_cxx_compiler_candidate "${_tr_macos_tool_path}/clang++-mp-${_tr_macos_versioned_llvm_version}")
        if(EXISTS "${_tr_macos_c_compiler_candidate}" AND EXISTS "${_tr_macos_cxx_compiler_candidate}")
            set(_tr_macos_versioned_c_compiler "${_tr_macos_c_compiler_candidate}")
            set(_tr_macos_versioned_cxx_compiler "${_tr_macos_cxx_compiler_candidate}")
            break()
        endif()
    endforeach()
endif()

if(NOT CMAKE_C_COMPILER)
    if(_tr_macos_versioned_c_compiler)
        set(TR_MACOS_C_COMPILER "${_tr_macos_versioned_c_compiler}")
    else()
        find_program(_tr_macos_unversioned_c_compiler
            NAMES clang
            PATHS ${_tr_macos_tool_paths})
        if(_tr_macos_unversioned_c_compiler)
            set(TR_MACOS_C_COMPILER "${_tr_macos_unversioned_c_compiler}")
        endif()
    endif()

    if(TR_MACOS_C_COMPILER)
        set(CMAKE_C_COMPILER "${TR_MACOS_C_COMPILER}"
            CACHE FILEPATH "C compiler for the macOS compatibility build" FORCE)
    endif()
endif()

if(NOT CMAKE_CXX_COMPILER)
    if(_tr_macos_versioned_cxx_compiler)
        set(TR_MACOS_CXX_COMPILER "${_tr_macos_versioned_cxx_compiler}")
    else()
        find_program(_tr_macos_unversioned_cxx_compiler
            NAMES clang++
            PATHS ${_tr_macos_tool_paths})
        if(_tr_macos_unversioned_cxx_compiler)
            set(TR_MACOS_CXX_COMPILER "${_tr_macos_unversioned_cxx_compiler}")
        endif()
    endif()

    if(TR_MACOS_CXX_COMPILER)
        set(CMAKE_CXX_COMPILER "${TR_MACOS_CXX_COMPILER}"
            CACHE FILEPATH "C++ compiler for the macOS compatibility build" FORCE)
    endif()
endif()

set(_tr_macos_active_llvm_version)
if(DEFINED CMAKE_CXX_COMPILER AND NOT "${CMAKE_CXX_COMPILER}" STREQUAL "")
    if("${CMAKE_CXX_COMPILER}" MATCHES "/clang\\+\\+-mp-([0-9]+)$")
        set(_tr_macos_active_llvm_version "${CMAKE_MATCH_1}")
    elseif("${CMAKE_CXX_COMPILER}" MATCHES "/libexec/llvm-([0-9]+)/bin/clang\\+\\+$")
        set(_tr_macos_active_llvm_version "${CMAKE_MATCH_1}")
    endif()
endif()

set(_tr_macos_llvm_prefixes ${CMAKE_PREFIX_PATH})
list(APPEND _tr_macos_llvm_prefixes "/opt/local")
list(REMOVE_DUPLICATES _tr_macos_llvm_prefixes)

set(_tr_macos_llvm_libexec_dirs)
if(_tr_macos_active_llvm_version)
    foreach(_tr_macos_prefix IN LISTS _tr_macos_llvm_prefixes)
        list(APPEND _tr_macos_llvm_libexec_dirs
            "${_tr_macos_prefix}/libexec/llvm-${_tr_macos_active_llvm_version}")
    endforeach()
endif()

set(_tr_macos_installed_llvm_versions)
if(_tr_macos_active_llvm_version OR NOT _tr_macos_cxx_compiler_provided)
    foreach(_tr_macos_prefix IN LISTS _tr_macos_llvm_prefixes)
        file(GLOB _tr_macos_prefix_llvm_libexec_dirs
            LIST_DIRECTORIES true
            "${_tr_macos_prefix}/libexec/llvm-*")
        foreach(_tr_macos_prefix_llvm_libexec_dir IN LISTS _tr_macos_prefix_llvm_libexec_dirs)
            if(_tr_macos_prefix_llvm_libexec_dir MATCHES "/llvm-([0-9]+)$")
                set(_tr_macos_installed_llvm_version "${CMAKE_MATCH_1}")
                if(NOT _tr_macos_installed_llvm_version VERSION_LESS TR_MACOS_LLVM_MIN_VERSION)
                    list(APPEND _tr_macos_installed_llvm_versions "${_tr_macos_installed_llvm_version}")
                endif()
            endif()
        endforeach()
    endforeach()
endif()

if(_tr_macos_installed_llvm_versions)
    list(REMOVE_DUPLICATES _tr_macos_installed_llvm_versions)
    list(SORT _tr_macos_installed_llvm_versions COMPARE NATURAL ORDER DESCENDING)
    foreach(_tr_macos_installed_llvm_version IN LISTS _tr_macos_installed_llvm_versions)
        foreach(_tr_macos_prefix IN LISTS _tr_macos_llvm_prefixes)
            set(_tr_macos_installed_llvm_libexec_dir
                "${_tr_macos_prefix}/libexec/llvm-${_tr_macos_installed_llvm_version}")
            if(IS_DIRECTORY "${_tr_macos_installed_llvm_libexec_dir}")
                list(APPEND _tr_macos_llvm_libexec_dirs
                    "${_tr_macos_installed_llvm_libexec_dir}")
            endif()
        endforeach()
    endforeach()
endif()

if(_tr_macos_llvm_libexec_dirs)
    list(REMOVE_DUPLICATES _tr_macos_llvm_libexec_dirs)
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

set(_tr_macos_libcxx_candidate_dirs ${_tr_macos_llvm_libexec_dirs})
foreach(_tr_macos_prefix IN LISTS _tr_macos_llvm_prefixes)
    file(GLOB _tr_macos_prefix_libcxx_libexec_dirs
        LIST_DIRECTORIES true
        "${_tr_macos_prefix}/libexec/llvm-*")
    list(APPEND _tr_macos_libcxx_candidate_dirs ${_tr_macos_prefix_libcxx_libexec_dirs})
endforeach()
if(_tr_macos_libcxx_candidate_dirs)
    list(REMOVE_DUPLICATES _tr_macos_libcxx_candidate_dirs)
endif()

set(_tr_macos_required_libcxx_arches)
if(CMAKE_OSX_ARCHITECTURES)
    list(APPEND _tr_macos_required_libcxx_arches ${CMAKE_OSX_ARCHITECTURES})
endif()

find_program(TR_MACOS_LIPO
    NAMES lipo
    PATHS ${_tr_macos_tool_paths} /usr/bin)

foreach(_tr_macos_llvm_libexec_dir IN LISTS _tr_macos_libcxx_candidate_dirs)
    set(_tr_macos_libcxx_dir "${_tr_macos_llvm_libexec_dir}/lib/libc++")
    if(NOT EXISTS "${_tr_macos_libcxx_dir}/libc++.dylib"
            AND EXISTS "${_tr_macos_llvm_libexec_dir}/lib/libc++.dylib")
        set(_tr_macos_libcxx_dir "${_tr_macos_llvm_libexec_dir}/lib")
    endif()
    if(EXISTS "${_tr_macos_libcxx_dir}/libc++.dylib")
        set(_tr_macos_libcxx_usable ON)
        if(TR_MACOS_LIPO AND _tr_macos_required_libcxx_arches)
            foreach(_tr_macos_required_libcxx_arch IN LISTS _tr_macos_required_libcxx_arches)
                foreach(_tr_macos_libcxx_file IN ITEMS
                        "${_tr_macos_libcxx_dir}/libc++.dylib"
                        "${_tr_macos_libcxx_dir}/libc++abi.dylib"
                        "${_tr_macos_libcxx_dir}/libunwind.dylib")
                    if(EXISTS "${_tr_macos_libcxx_file}")
                        execute_process(
                            COMMAND "${TR_MACOS_LIPO}" "${_tr_macos_libcxx_file}" -verify_arch "${_tr_macos_required_libcxx_arch}"
                            RESULT_VARIABLE _tr_macos_libcxx_arch_result
                            OUTPUT_QUIET
                            ERROR_QUIET)
                        if(NOT _tr_macos_libcxx_arch_result EQUAL 0)
                            set(_tr_macos_libcxx_usable OFF)
                        endif()
                    endif()
                endforeach()
            endforeach()
        endif()
        if(NOT _tr_macos_libcxx_usable)
            continue()
        endif()

        set(_tr_macos_libcxx_stdlib_flag "-stdlib=libc++")
        set(_tr_macos_libcxx_link_flags "-L${_tr_macos_libcxx_dir}")
        if(NOT CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS 10.5)
            string(APPEND _tr_macos_libcxx_link_flags " -Wl,-rpath,${_tr_macos_libcxx_dir}")
        endif()
        set(_tr_macos_libcxx_companion_libraries)
        set(TR_MACOS_LIBCXX_RUNTIME_DIR "${_tr_macos_libcxx_dir}"
            CACHE PATH "libc++ runtime directory for macOS compatibility bundle fixups" FORCE)

        if(EXISTS "${_tr_macos_libcxx_dir}/libc++abi.dylib")
            list(APPEND _tr_macos_libcxx_companion_libraries "-lc++abi")
        endif()

        if(EXISTS "${_tr_macos_libcxx_dir}/libunwind.dylib")
            list(APPEND _tr_macos_libcxx_companion_libraries "-lunwind")
        endif()

        foreach(_tr_macos_cxx_flags_var
                CMAKE_CXX_FLAGS_INIT
                CMAKE_OBJCXX_FLAGS_INIT
                CMAKE_CXX_FLAGS
                CMAKE_OBJCXX_FLAGS)
            string(FIND "${${_tr_macos_cxx_flags_var}}" "${_tr_macos_libcxx_stdlib_flag}" _tr_macos_libcxx_stdlib_flag_pos)
            if(_tr_macos_libcxx_stdlib_flag_pos EQUAL -1)
                string(APPEND ${_tr_macos_cxx_flags_var}
                    " ${_tr_macos_libcxx_stdlib_flag}")
                if(NOT _tr_macos_cxx_flags_var MATCHES "_INIT$")
                    set(${_tr_macos_cxx_flags_var} "${${_tr_macos_cxx_flags_var}}"
                        CACHE STRING "Compiler flags for the macOS compatibility build" FORCE)
                endif()
            endif()
        endforeach()

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

        foreach(_tr_macos_cxx_libraries_var
                CMAKE_CXX_STANDARD_LIBRARIES_INIT
                CMAKE_CXX_STANDARD_LIBRARIES)
            foreach(_tr_macos_libcxx_companion_library IN LISTS _tr_macos_libcxx_companion_libraries)
                string(FIND "${${_tr_macos_cxx_libraries_var}}" "${_tr_macos_libcxx_companion_library}" _tr_macos_libcxx_companion_library_pos)
                if(_tr_macos_libcxx_companion_library_pos EQUAL -1)
                    string(APPEND ${_tr_macos_cxx_libraries_var}
                        " ${_tr_macos_libcxx_companion_library}")
                endif()
            endforeach()

            if(NOT _tr_macos_cxx_libraries_var MATCHES "_INIT$")
                set(${_tr_macos_cxx_libraries_var} "${${_tr_macos_cxx_libraries_var}}"
                    CACHE STRING "C++ standard libraries for the macOS compatibility build" FORCE)
            endif()
        endforeach()
        break()
    endif()
endforeach()
