# Build the Snow Leopard Sparkle framework from Transmission's pinned source and patches.

include_guard(GLOBAL)

function(tr_add_sparkle_source_build)
    set(sparkle_source "${CMAKE_SOURCE_DIR}/third-party/sparkle")
    set(sparkle_patch_dir "${CMAKE_SOURCE_DIR}/third-party/patches/sparkle")
    if(NOT EXISTS "${sparkle_source}/Sparkle.xcodeproj/project.pbxproj")
        message(FATAL_ERROR "Missing pinned Sparkle 1.27.3 source")
    endif()

    file(GLOB_RECURSE sparkle_sources CONFIGURE_DEPENDS LIST_DIRECTORIES FALSE
        "${sparkle_source}/*")
    file(GLOB sparkle_patches CONFIGURE_DEPENDS "${sparkle_patch_dir}/*.patch")
    list(SORT sparkle_patches)
    if(NOT sparkle_patches)
        message(FATAL_ERROR "Missing Sparkle compatibility patches")
    endif()

    find_program(TR_SPARKLE_PATCH_EXECUTABLE patch REQUIRED)
    find_program(TR_SPARKLE_XCODEBUILD_EXECUTABLE xcodebuild REQUIRED)
    find_program(TR_SPARKLE_IBTOOL_EXECUTABLE ibtool REQUIRED)
    find_program(TR_SPARKLE_OTOOL_EXECUTABLE otool REQUIRED)

    set(sparkle_overlay "${CMAKE_BINARY_DIR}/sparkle-source")
    set(sparkle_products "${CMAKE_BINARY_DIR}/sparkle-products")
    set(sparkle_objects "${CMAKE_BINARY_DIR}/sparkle-objects")
    set(sparkle_framework "${sparkle_products}/Release/Sparkle.framework")
    set(sparkle_resources "${sparkle_framework}/Versions/A/Resources")
    set(sparkle_snow_nibs "${sparkle_resources}/LegacySnow")
    set(sparkle_autoupdate
        "${sparkle_resources}/Autoupdate.app/Contents")
    set(sparkle_arc_support
        "${sparkle_autoupdate}/Frameworks/libarc_support.dylib")
    set(sparkle_stamp "${sparkle_products}/Release/.transmission-sparkle.stamp")
    set(sparkle_compiler_driver
        "${CMAKE_SOURCE_DIR}/cmake/apple-link-tools/sparkle-clang-snow")

    set(sparkle_linker "${CMAKE_LINKER}")
    if(EXISTS "/Developer/usr/bin/ld")
        set(sparkle_linker "/Developer/usr/bin/ld")
    endif()
    if(NOT EXISTS "${sparkle_linker}")
        message(FATAL_ERROR "Sparkle linker does not exist: ${sparkle_linker}")
    endif()

    set(sparkle_patch_commands)
    foreach(sparkle_patch IN LISTS sparkle_patches)
        list(APPEND sparkle_patch_commands
            COMMAND "${CMAKE_COMMAND}" -E chdir "${sparkle_overlay}"
                "${TR_SPARKLE_PATCH_EXECUTABLE}"
                --batch --forward --fuzz=0 -p1 -i "${sparkle_patch}")
    endforeach()

    add_custom_command(
        OUTPUT "${sparkle_stamp}"
        BYPRODUCTS
            "${sparkle_framework}/Versions/A/Sparkle"
            "${sparkle_autoupdate}/MacOS/Autoupdate"
            "${sparkle_autoupdate}/MacOS/fileop"
            "${sparkle_arc_support}"
            "${sparkle_snow_nibs}/SUUpdatePermissionPrompt.nib"
            "${sparkle_snow_nibs}/SUAutomaticUpdateAlert.nib"
            "${sparkle_snow_nibs}/SUUpdateAlert.nib"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${sparkle_overlay}"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${sparkle_products}"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${sparkle_objects}"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${sparkle_source}" "${sparkle_overlay}"
        ${sparkle_patch_commands}
        COMMAND "${CMAKE_COMMAND}" -E chdir "${sparkle_overlay}"
            "${CMAKE_COMMAND}" -E env
            "TR_SPARKLE_C_COMPILER=${CMAKE_C_COMPILER}"
            "TR_SPARKLE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
            "TR_SPARKLE_LINKER=${sparkle_linker}"
            "${TR_SPARKLE_XCODEBUILD_EXECUTABLE}"
            -project Sparkle.xcodeproj
            -target Sparkle
            -configuration Release
            "ARCHS=x86_64"
            "ONLY_ACTIVE_ARCH=YES"
            "CC=${sparkle_compiler_driver}"
            "CPLUSPLUS=${sparkle_compiler_driver}"
            "LD=${sparkle_compiler_driver}"
            "LDPLUSPLUS=${sparkle_compiler_driver}"
            "SDKROOT=${CMAKE_OSX_SYSROOT}"
            "MACOSX_DEPLOYMENT_TARGET=10.6"
            "SPARKLE_GIT_DESCRIBE=1.27.3"
            "CLANG_ENABLE_MODULES=NO"
            "ENABLE_HARDENED_RUNTIME=NO"
            "WARNING_CFLAGS_EXTRA=-Wno-custom-atomic-properties -Wno-implicit-atomic-properties -Wno-unsafe-buffer-usage"
            "GCC_PREFIX_HEADER=Sparkle/SULegacyCompatibility.h"
            "GCC_PRECOMPILE_PREFIX_HEADER=NO"
            "TR_ARC_SUPPORT_DYLIB=$<TARGET_FILE:arc_support>"
            "OBJROOT=${sparkle_objects}"
            "SYMROOT=${sparkle_products}"
            "CODE_SIGNING_REQUIRED=NO"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${sparkle_snow_nibs}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${sparkle_snow_nibs}"
        COMMAND "${TR_SPARKLE_IBTOOL_EXECUTABLE}" --compile
            "${sparkle_snow_nibs}/SUUpdatePermissionPrompt.nib"
            "${sparkle_overlay}/Sparkle/Base.lproj/SUUpdatePermissionPrompt.xib"
            --sdk "${CMAKE_OSX_SYSROOT}"
        COMMAND "${TR_SPARKLE_IBTOOL_EXECUTABLE}" --compile
            "${sparkle_snow_nibs}/SUAutomaticUpdateAlert.nib"
            "${sparkle_overlay}/Sparkle/Base.lproj/SUAutomaticUpdateAlert.xib"
            --sdk "${CMAKE_OSX_SYSROOT}"
        COMMAND "${TR_SPARKLE_IBTOOL_EXECUTABLE}" --compile
            "${sparkle_snow_nibs}/SUUpdateAlert.nib"
            "${sparkle_overlay}/Sparkle/Base.lproj/SUUpdateAlert.xib"
            --sdk "${CMAKE_OSX_SYSROOT}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${sparkle_autoupdate}/Frameworks"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "$<TARGET_FILE:arc_support>" "${sparkle_arc_support}"
        COMMAND "${CMAKE_COMMAND}" -E touch "${sparkle_stamp}"
        DEPENDS
            ${sparkle_sources}
            ${sparkle_patches}
            arc_support
            "${sparkle_compiler_driver}"
            "${CMAKE_SOURCE_DIR}/cmake/apple-link-tools/ld"
        COMMENT "Building patched Sparkle 1.27.3"
        VERBATIM)

    add_custom_target(tr_sparkle DEPENDS "${sparkle_stamp}")
    set(TR_SPARKLE_FRAMEWORK_PATH "${sparkle_framework}" PARENT_SCOPE)
    set(TR_SPARKLE_OTOOL_EXECUTABLE
        "${TR_SPARKLE_OTOOL_EXECUTABLE}" PARENT_SCOPE)
endfunction()
