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
