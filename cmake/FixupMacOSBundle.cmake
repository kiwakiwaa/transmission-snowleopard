if(NOT DEFINED TR_BUNDLE_DIR)
    message(FATAL_ERROR "TR_BUNDLE_DIR is required")
endif()
if(NOT DEFINED TR_BUNDLE_ITEMS)
    message(FATAL_ERROR "TR_BUNDLE_ITEMS is required")
endif()

if(DEFINED TR_CMAKE_MODULE_PATH)
    list(APPEND CMAKE_MODULE_PATH "${TR_CMAKE_MODULE_PATH}")
endif()

include(TrMacros)
include(GetPrerequisites)
include(BundleUtilities)

if(DEFINED TR_DEP_LINK_PREFIX)
    set(TR_FIXUP_BUNDLE_DEP_LINK_PREFIX "${TR_DEP_LINK_PREFIX}")
endif()

tr_fixup_bundle_item("${TR_BUNDLE_DIR}" "${TR_BUNDLE_ITEMS}" "${TR_DEP_DIRS}")

set(TR_BUNDLED_LIBCXX "${TR_BUNDLE_DIR}/Contents/Frameworks/libc++.1.dylib")
set(TR_BUNDLED_LIBCXXABI "${TR_BUNDLE_DIR}/Contents/Frameworks/libc++abi.1.dylib")
if(EXISTS "${TR_BUNDLED_LIBCXX}" AND EXISTS "${TR_BUNDLED_LIBCXXABI}")
    get_filename_component(TR_BUNDLED_LIBCXX_REALPATH "${TR_BUNDLED_LIBCXX}" REALPATH)
    execute_process(
        COMMAND install_name_tool
            -change /usr/lib/libc++abi.dylib
            @loader_path/libc++abi.1.dylib
            "${TR_BUNDLED_LIBCXX_REALPATH}"
        RESULT_VARIABLE TR_BUNDLED_LIBCXX_FIXUP_RESULT
        ERROR_VARIABLE TR_BUNDLED_LIBCXX_FIXUP_ERROR)
    if(NOT TR_BUNDLED_LIBCXX_FIXUP_RESULT EQUAL 0)
        message(FATAL_ERROR "Could not fix bundled libc++ dependency: ${TR_BUNDLED_LIBCXX_FIXUP_ERROR}")
    endif()
endif()
