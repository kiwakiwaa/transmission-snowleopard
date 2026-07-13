if(NOT APPLE)
    return()
endif()

set(TR_LIBARC_SUPPORT_SOURCE_DIR "${TR_THIRD_PARTY_SOURCE_DIR}/libarc_support")

if(NOT EXISTS "${TR_LIBARC_SUPPORT_SOURCE_DIR}/include/libarc_support/arc_runtime.h")
    if(TR_MACOS_DEPLOYMENT_BEFORE_10_7)
        message(FATAL_ERROR "macOS builds before 10.7 require third-party/libarc_support")
    endif()
    return()
endif()

enable_language(OBJC)

set(TR_LIBARC_SUPPORT_SOURCES
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/src/arc_core.m"
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/src/arc_alloc.m"
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/src/arc_bridge.m"
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/src/arc_pool.m"
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/src/arc_weak_table.m"
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/src/arc_weak_runtime.m")

add_library(_libarc_support_runtime SHARED EXCLUDE_FROM_ALL
    ${TR_LIBARC_SUPPORT_SOURCES})
add_library(libarc_support::runtime ALIAS _libarc_support_runtime)

target_include_directories(_libarc_support_runtime
    PUBLIC
        "${TR_LIBARC_SUPPORT_SOURCE_DIR}/include"
    PRIVATE
        "${TR_LIBARC_SUPPORT_SOURCE_DIR}/private")

set(TR_LIBARC_SUPPORT_OBJC_RUNTIME_COMPILE_OPTIONS)
if(TR_MACOS_OBJC_FRAGILE_RUNTIME)
    list(LENGTH CMAKE_OSX_ARCHITECTURES TR_LIBARC_SUPPORT_ARCH_COUNT)
    if(TR_LIBARC_SUPPORT_ARCH_COUNT EQUAL 1)
        list(APPEND TR_LIBARC_SUPPORT_OBJC_RUNTIME_COMPILE_OPTIONS "$<$<COMPILE_LANGUAGE:OBJC>:-fobjc-runtime=macosx-fragile-10.7>")
    else()
        list(APPEND TR_LIBARC_SUPPORT_OBJC_RUNTIME_COMPILE_OPTIONS "$<$<COMPILE_LANGUAGE:OBJC>:SHELL:-Xarch_i386 -fobjc-runtime=macosx-fragile-10.7>")
    endif()
endif()

target_compile_options(_libarc_support_runtime
    PRIVATE
        $<$<COMPILE_LANGUAGE:OBJC>:-fno-objc-arc>
        $<$<COMPILE_LANGUAGE:OBJC>:-fvisibility=hidden>
        ${TR_LIBARC_SUPPORT_OBJC_RUNTIME_COMPILE_OPTIONS})

target_link_libraries(_libarc_support_runtime
    PRIVATE
        "-framework CoreFoundation"
        "-framework Foundation"
        "-lobjc")

set(TR_BLOCKS_RUNTIME_LIBRARY_DIRS)
foreach(TR_BLOCKS_RUNTIME_PREFIX IN LISTS CMAKE_PREFIX_PATH)
    list(APPEND TR_BLOCKS_RUNTIME_LIBRARY_DIRS "${TR_BLOCKS_RUNTIME_PREFIX}/lib")
endforeach()
list(APPEND TR_BLOCKS_RUNTIME_LIBRARY_DIRS
    /opt/local/lib
    /usr/local/lib
    "${TR_LIBARC_SUPPORT_SOURCE_DIR}/vendor/blocks-runtime-tiger/lib")

find_library(TR_BLOCKS_RUNTIME_LIBRARY BlocksRuntime
    PATHS
        ${TR_BLOCKS_RUNTIME_LIBRARY_DIRS}
    NO_DEFAULT_PATH)
if(TR_BLOCKS_RUNTIME_LIBRARY)
    target_link_libraries(_libarc_support_runtime
        PRIVATE
            "${TR_BLOCKS_RUNTIME_LIBRARY}")
else()
    message(FATAL_ERROR "libarc_support requires BlocksRuntime; install libblocksruntime or set TR_BLOCKS_RUNTIME_LIBRARY")
endif()

target_link_options(_libarc_support_runtime
    PRIVATE
        "LINKER:-exported_symbols_list,${TR_LIBARC_SUPPORT_SOURCE_DIR}/exports/libarc_support.exp")

set_target_properties(_libarc_support_runtime
    PROPERTIES
        BUILD_WITH_INSTALL_NAME_DIR ON
        FOLDER "${TR_THIRD_PARTY_DIR_NAME}"
        INSTALL_NAME_DIR ""
        MACOSX_RPATH OFF
        OUTPUT_NAME arc_support)
