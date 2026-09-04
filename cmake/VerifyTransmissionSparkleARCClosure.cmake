cmake_policy(SET CMP0009 NEW)

if(NOT DEFINED TR_APP_BUNDLE OR NOT IS_DIRECTORY "${TR_APP_BUNDLE}" OR
   NOT DEFINED TR_APP_EXECUTABLE OR TR_APP_EXECUTABLE STREQUAL "")
    message(FATAL_ERROR "Transmission ARC closure check is missing its app bundle")
endif()
if(NOT DEFINED TR_NM_EXECUTABLE OR TR_NM_EXECUTABLE STREQUAL "")
    set(TR_NM_EXECUTABLE /usr/bin/nm)
endif()
if(NOT DEFINED TR_OTOOL_EXECUTABLE OR TR_OTOOL_EXECUTABLE STREQUAL "")
    set(TR_OTOOL_EXECUTABLE /usr/bin/otool)
endif()

set(_contents "${TR_APP_BUNDLE}/Contents")
set(_app "${_contents}/MacOS/${TR_APP_EXECUTABLE}")
set(_framework "${_contents}/Frameworks/Sparkle.framework/Versions/A/Sparkle")
set(_updater_root
    "${_contents}/Frameworks/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents")
set(_updater "${_updater_root}/MacOS/Autoupdate")
set(_fileop "${_updater_root}/MacOS/fileop")
set(_app_runtime "${_contents}/Frameworks/libarc_support.dylib")
set(_updater_runtime "${_updater_root}/Frameworks/libarc_support.dylib")

foreach(_required IN ITEMS
        "${_app}" "${_framework}" "${_updater}" "${_fileop}"
        "${_app_runtime}" "${_updater_runtime}")
    if(NOT EXISTS "${_required}")
        message(FATAL_ERROR "Transmission ARC closure member is missing: ${_required}")
    endif()
endforeach()

file(SHA256 "${_app_runtime}" _app_runtime_digest)
file(SHA256 "${_updater_runtime}" _updater_runtime_digest)
if(NOT _app_runtime_digest STREQUAL _updater_runtime_digest)
    message(FATAL_ERROR "Transmission embeds different ARC runtime binaries")
endif()

file(GLOB_RECURSE _providers
    LIST_DIRECTORIES false "${_contents}/*libarc_support.dylib")
list(LENGTH _providers _provider_count)
if(NOT _provider_count EQUAL 2)
    message(FATAL_ERROR
        "Transmission must contain one ARC provider for each executable closure")
endif()

execute_process(
    COMMAND "${TR_OTOOL_EXECUTABLE}" -l "${_app}"
    RESULT_VARIABLE _load_commands_result
    OUTPUT_VARIABLE _load_commands
    ERROR_VARIABLE _load_commands_error)
if(NOT _load_commands_result EQUAL 0 OR
   NOT _load_commands MATCHES
       "path @executable_path/../Frameworks \\(offset [0-9]+\\)")
    message(FATAL_ERROR
        "Transmission lacks its bundle-relative framework rpath: ${_load_commands_error}")
endif()

foreach(_image IN ITEMS "${_app}" "${_framework}" "${_updater}" "${_fileop}")
    execute_process(
        COMMAND "${TR_OTOOL_EXECUTABLE}" -L "${_image}"
        RESULT_VARIABLE _otool_result
        OUTPUT_VARIABLE _otool_output
        ERROR_VARIABLE _otool_error)
    if(NOT _otool_result EQUAL 0 OR
       NOT _otool_output MATCHES
           "@executable_path/../Frameworks/libarc_support[.]dylib")
        message(FATAL_ERROR
            "Transmission image lacks its ARC provider: ${_image}: ${_otool_error}")
    endif()

    execute_process(
        COMMAND "${TR_NM_EXECUTABLE}" -m "${_image}"
        RESULT_VARIABLE _nm_result
        OUTPUT_VARIABLE _nm_output
        ERROR_VARIABLE _nm_error)
    if(NOT _nm_result EQUAL 0 OR
       _nm_output MATCHES "dynamically looked up" OR
       _nm_output MATCHES "libarc_support_(fallback|target)_")
        message(FATAL_ERROR
            "Transmission image bypasses its ARC provider: ${_image}: ${_nm_error}")
    endif()
endforeach()
