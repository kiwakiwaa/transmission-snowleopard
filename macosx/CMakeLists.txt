# minimum macOS target support
if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS TR_MACOS_LEGACY_SUPPORT_MINIMUM)
    message(FATAL_ERROR "Targeting macOS versions before ${TR_MACOS_LEGACY_SUPPORT_MINIMUM} is not supported for the macOS project, please adjust CMAKE_OSX_DEPLOYMENT_TARGET (${CMAKE_OSX_DEPLOYMENT_TARGET})")
endif()

set(TR_MACOS_USE_SOURCE_IMAGE_ASSETS OFF)
if(TR_MACOS_DEPLOYMENT_BEFORE_10_8)
    set(TR_MACOS_USE_SOURCE_IMAGE_ASSETS ON)
endif()

find_program(CODESIGN_EXECUTABLE codesign REQUIRED)
find_program(XCRUN_EXECUTABLE xcrun)
if(XCRUN_EXECUTABLE)
    execute_process(
        COMMAND ${XCRUN_EXECUTABLE} -find codesign_allocate
        OUTPUT_VARIABLE TR_MACOS_XCRUN_CODESIGN_ALLOCATE_EXECUTABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE TR_MACOS_XCRUN_CODESIGN_ALLOCATE_RESULT
        ERROR_QUIET)
    if(TR_MACOS_XCRUN_CODESIGN_ALLOCATE_RESULT EQUAL 0 AND EXISTS "${TR_MACOS_XCRUN_CODESIGN_ALLOCATE_EXECUTABLE}")
        set(CODESIGN_ALLOCATE_EXECUTABLE "${TR_MACOS_XCRUN_CODESIGN_ALLOCATE_EXECUTABLE}"
            CACHE FILEPATH "codesign_allocate executable" FORCE)
    endif()
endif()
if(NOT CODESIGN_ALLOCATE_EXECUTABLE)
    find_program(CODESIGN_ALLOCATE_EXECUTABLE codesign_allocate)
endif()
if(TR_MACOS_USE_SOURCE_IMAGE_ASSETS)
    find_program(SIPS_EXECUTABLE sips REQUIRED)
else()
    find_program(ACTOOL_EXECUTABLE actool REQUIRED)
endif()

set(TR_OBJC_WEAK_PROPERTY weak)
set(TR_OBJC_WEAK_REF __weak)
set(TR_MACOS_OBJC_ARC_COMPILE_OPTIONS "$<$<COMPILE_LANGUAGE:C,CXX>:-fobjc-arc>")
set(TR_MACOS_OBJC_WEAK_COMPILE_OPTIONS "$<$<COMPILE_LANGUAGE:C,CXX>:-fobjc-weak>")
set(TR_MACOS_ARCLITE_LINK_OPTIONS)
if(TR_MACOS_DEPLOYMENT_BEFORE_10_7)
    set(TR_MACOS_OBJC_WEAK_COMPILE_OPTIONS "$<$<COMPILE_LANGUAGE:C,CXX>:SHELL:-Xclang -fobjc-runtime-has-weak>")

    if(NOT TR_MACOS_ARCLITE_LIBRARY OR NOT EXISTS "${TR_MACOS_ARCLITE_LIBRARY}")
        message(FATAL_ERROR "Snow Leopard ARC builds require libarclite_macosx.a, but TR_MACOS_ARCLITE_LIBRARY is not set")
    endif()

    list(APPEND TR_MACOS_ARCLITE_LINK_OPTIONS "$<$<LINK_LANGUAGE:C,CXX>:-Wl,-force_load,${TR_MACOS_ARCLITE_LIBRARY}>")

    # ARC-lite patches these lazy runtime/class references on 10.6 at load time.
    foreach(TR_MACOS_ARCLITE_SYMBOL IN ITEMS
            _objc_retain
            _objc_release
            _objc_autorelease
            _objc_retainAutorelease
            _objc_retainAutoreleaseReturnValue
            _objc_retainAutoreleasedReturnValue
            _objc_unsafeClaimAutoreleasedReturnValue
            _objc_autoreleaseReturnValue
            _objc_storeStrong
            _objc_retainBlock
            _objc_autoreleasePoolPush
            _objc_autoreleasePoolPop
            _objc_alloc
            _objc_allocWithZone
            _objc_alloc_init
            _OBJC_CLASS_$_NSOrderedSet
            _OBJC_CLASS_$_NSMutableOrderedSet)
        list(APPEND TR_MACOS_ARCLITE_LINK_OPTIONS "$<$<LINK_LANGUAGE:C,CXX>:-Wl,-U,${TR_MACOS_ARCLITE_SYMBOL}>")
    endforeach()
endif()

add_compile_definitions(
    TR_OBJC_WEAK=${TR_OBJC_WEAK_PROPERTY}
    TR_OBJC_WEAK_REF=${TR_OBJC_WEAK_REF})

set(MAC_BUNDLE_NAME Transmission)

add_compile_options(
    $<$<COMPILE_LANGUAGE:C>:-fmodules>

    # https://github.com/llvm/llvm-project/issues/57432
    "$<$<COMPILE_LANG_AND_ID:CXX,AppleClang,Clang>:-fno-modules;-Xclang;-fno-cxx-modules>"

    # equivalent of XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES for this directory
    ${TR_MACOS_OBJC_ARC_COMPILE_OPTIONS}

    # equivalent of XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_WEAK YES for this directory
    ${TR_MACOS_OBJC_WEAK_COMPILE_OPTIONS}

    # GNU extensions are good practice in Objective-C
    $<$<COMPILE_LANGUAGE:C,CXX>:-Wno-gnu>

    # Our #warnings are good practice in IDE development, not in command-line compilation
    $<$<AND:$<NOT:$<BOOL:${XCODE}>>,$<COMPILE_LANGUAGE:C,CXX>>:-Wno-\#warnings>)

add_link_options(
    # equivalent of XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING YES for this directory
    $<$<LINK_LANGUAGE:C,CXX>:-dead_strip>
    ${TR_MACOS_ARCLITE_LINK_OPTIONS})

if(NOT TR_MACOS_DEPLOYMENT_BEFORE_12_0)
    add_subdirectory(QuickLookExtension)
endif()
add_subdirectory(QuickLookPlugin)
add_subdirectory(VDKQueue)

add_executable(${TR_NAME}-mac MACOSX_BUNDLE)

set(TR_ENABLE_SPARKLE ON)
if(TR_MACOS_DEPLOYMENT_BEFORE_10_11)
    set(TR_ENABLE_SPARKLE OFF)
endif()

set(TR_MACOS_XIB_COMPAT_10_6 OFF)
set(TR_MACOS_XIB_COMPAT_10_7 OFF)
set(TR_MACOS_XIB_COMPAT_10_8 OFF)
set(TR_MACOS_XIB_COMPAT_10_9 OFF)
set(TR_MACOS_XIB_COMPAT_LEGACY_IBTOOL OFF)
set(TR_MACOS_USES_MAVERICKS_STACK_XIBS OFF)
set(TR_MACOS_USES_COMPAT_STACK_XIBS OFF)
if(TR_MACOS_DEPLOYMENT_BEFORE_10_7)
    set(TR_MACOS_XIB_COMPAT_10_6 ON)
elseif(TR_MACOS_DEPLOYMENT_BEFORE_10_8)
    set(TR_MACOS_XIB_COMPAT_10_7 ON)
elseif(TR_MACOS_DEPLOYMENT_BEFORE_10_9)
    set(TR_MACOS_XIB_COMPAT_10_8 ON)
elseif(TR_MACOS_DEPLOYMENT_BEFORE_10_10)
    set(TR_MACOS_XIB_COMPAT_10_9 ON)
endif()
if(TR_MACOS_XIB_COMPAT_10_6 OR TR_MACOS_XIB_COMPAT_10_7)
    set(TR_MACOS_XIB_COMPAT_LEGACY_IBTOOL ON)
endif()
if(NOT TR_MACOS_DEPLOYMENT_BEFORE_10_9 AND TR_MACOS_DEPLOYMENT_BEFORE_10_11)
    set(TR_MACOS_USES_MAVERICKS_STACK_XIBS ON)
endif()
if(TR_MACOS_XIB_COMPAT_LEGACY_IBTOOL OR TR_MACOS_XIB_COMPAT_10_8 OR TR_MACOS_USES_MAVERICKS_STACK_XIBS)
    set(TR_MACOS_USES_COMPAT_STACK_XIBS ON)
endif()

set(TR_SPARKLE_INFO_PLIST_KEYS "")
if(TR_ENABLE_SPARKLE)
    set(TR_SPARKLE_INFO_PLIST_KEYS [=[
	<key>SUAllowsAutomaticUpdates</key>
	<false/>
	<key>SUFeedURL</key>
	<string>https://update.transmissionbt.com/appcast.xml</string>
	<key>SUPublicDSAKeyFile</key>
	<string>sparkle_dsa_pub.pem</string>
	<key>SUScheduledCheckInterval</key>
	<string>86400</string>]=])
endif()

target_sources(${TR_NAME}-mac
    PRIVATE
        AboutWindowController.h
        AboutWindowController.mm
        AddMagnetWindowController.h
        AddMagnetWindowController.mm
        AddWindowController.h
        AddWindowController.mm
        Badger.h
        Badger.mm
        BadgeView.h
        BadgeView.mm
        BlocklistDownloader.h
        BlocklistDownloader.mm
        BlocklistDownloaderViewController.h
        BlocklistDownloaderViewController.mm
        BlocklistScheduler.h
        BlocklistScheduler.mm
        BonjourController.h
        BonjourController.mm
        ButtonToolbarItem.h
        ButtonToolbarItem.mm
        CocoaCompatibility.h
        CocoaCompatibility.mm
        LegacyRegularExpression.h
        LegacyRegularExpression.mm
        ColorTextField.h
        ColorTextField.mm
        ObjectiveCCompatibility.h
        Controller.h
        Controller.mm
        CreatorWindowController.h
        CreatorWindowController.mm
        DefaultAppHelper.h
        DefaultAppHelper.mm
        DragOverlayView.h
        DragOverlayView.mm
        DragOverlayWindow.h
        DragOverlayWindow.mm
        ExpandedPathToIconTransformer.h
        ExpandedPathToIconTransformer.mm
        ExpandedPathToPathTransformer.h
        ExpandedPathToPathTransformer.mm
        FileBatchRenameItem.h
        FileBatchRenameItem.mm
        FileBatchRenameSession.h
        FileBatchRenameSession.mm
        FileListNode.h
        FileListNode.mm
        FileCheckCellView.h
        FileCheckCellView.mm
        FileDescriptorLimit.h
        FileDescriptorLimit.mm
        FileNameCell.h
        FileNameCell.mm
        FileNameCellView.h
        FileNameCellView.mm
        FileOutlineItemDisplay.h
        FileOutlineItemDisplay.mm
        FileOutlineController.h
        FileOutlineController.mm
        FileOutlineView.h
        FileOutlineView.mm
        FilePriorityCell.h
        FilePriorityCell.mm
        FilePriorityCellView.h
        FilePriorityCellView.mm
        FileRenameSheetController.h
        FileRenameSheetController.mm
        RenameRule.h
        RenameRule.mm
        RenameRules.h
        RenameRules.mm
        FilterBarController.h
        FilterBarController.mm
        FilterButton.h
        FilterButton.mm
        GlobalOptionsPopoverViewController.h
        GlobalOptionsPopoverViewController.mm
        GroupCell.h
        GroupCell.mm
        GroupPopUpButtonCell.h
        GroupPopUpButtonCell.mm
        GroupsController.h
        GroupsController.mm
        GroupsPrefsController.h
        GroupsPrefsController.mm
        GroupToolbarItem.h
        GroupToolbarItem.mm
        InfoActivityViewController.h
        InfoActivityViewController.mm
        InfoFileViewController.h
        InfoFileViewController.mm
        InfoGeneralViewController.h
        InfoGeneralViewController.mm
        InfoOptionsViewController.h
        InfoOptionsViewController.mm
        InfoPeersViewController.h
        InfoPeersViewController.mm
        InfoTextField.h
        InfoTextField.mm
        InfoTrackersViewController.h
        InfoTrackersViewController.mm
        InfoViewController.h
        InfoWindow.h
        InfoWindow.mm
        InfoWindowController.h
        InfoWindowController.mm
        LegacyArchiving.h
        LegacyArchiving.mm
        LegacyColors.h
        LegacyColors.mm
        LegacyConstraints.h
        LegacyConstraints.mm
        LegacyFormatters.h
        LegacyFormatters.mm
        LegacyPowerActivity.h
        LegacyPowerActivity.mm
        LegacyPopover.h
        LegacySegmentedControl.h
        LegacySegmentedControl.mm
        LegacySheets.h
        LegacySheets.mm
        LegacyStackView.h
        LegacyStackView.mm
        LegacySubscripting.mm
        LegacySymbols.h
        LegacySymbols.mm
        LegacyTitlebarAccessory.h
        LegacyTitlebarAccessory.mm
        LegacyURLRequest.h
        LegacyURLRequest.mm
        main.mm
        MessageWindowController.h
        MessageWindowController.mm
        NSApplicationAdditions.h
        NSApplicationAdditions.mm
        NSDataAdditions.h
        NSDataAdditions.mm
        NSImageAdditions.h
        NSImageAdditions.mm
        NSMutableArrayAdditions.h
        NSMutableArrayAdditions.mm
        NSStringAdditions.h
        NSStringAdditions.mm
        PeerProgressIndicatorCell.h
        PeerProgressIndicatorCell.mm
        PeerTableView.h
        PeerTableView.mm
        PiecesView.h
        PiecesView.mm
        PortChecker.h
        PortChecker.mm
        PowerManager.h
        PowerManager.mm
        PredicateEditorRowTemplateAny.h
        PredicateEditorRowTemplateAny.mm
        PrefsController.h
        PrefsController.mm
        PrefsWindow.h
        PrefsWindow.mm
        PriorityPopUpButtonCell.h
        PriorityPopUpButtonCell.mm
        ProgressBarView.h
        ProgressBarView.mm
        ProgressGradients.h
        ProgressGradients.mm
        ShareToolbarItem.h
        ShareToolbarItem.mm
        ShareTorrentFileHelper.h
        ShareTorrentFileHelper.mm
        SmallTorrentCell.h
        SmallTorrentCell.mm
        StatsWindowController.h
        StatsWindowController.mm
        StatusBarController.h
        StatusBarController.mm
        SystemNotificationController.h
        SystemNotificationController.mm
        Toolbar.h
        Toolbar.mm
        Torrent.h
        Torrent.mm
        TorrentCell.h
        TorrentCell.mm
        TorrentCellActionButton.h
        TorrentCellActionButton.mm
        TorrentCellControlButton.h
        TorrentCellControlButton.mm
        TorrentCellRevealButton.h
        TorrentCellRevealButton.mm
        TorrentGroup.h
        TorrentGroup.mm
        TorrentTableView.h
        TorrentTableView.mm
        TrackerCell.h
        TrackerCell.mm
        TrackerNode.h
        TrackerNode.mm
        TrackerTableView.h
        TrackerTableView.mm
        URLSheetWindowController.h
        URLSheetWindowController.mm
        Utils.h
        Utils.mm
        VersionComparator.h
        VersionComparator.mm
        WebSeedTableView.h
        WebSeedTableView.mm)

if(TR_MACOS_DEPLOYMENT_BEFORE_10_8)
    target_sources(${TR_NAME}-mac
        PRIVATE
            PLWeakCompatibilityCore.h
            PLWeakCompatibilityCore.mm)
endif()

if(TR_MACOS_DEPLOYMENT_BEFORE_10_7)
    target_sources(${TR_NAME}-mac
        PRIVATE
            LegacyPopover.mm
            PLWeakCompatibilityStubs.h
            PLWeakCompatibilityStubs.mm)
elseif(TR_MACOS_DEPLOYMENT_BEFORE_10_8)
    target_sources(${TR_NAME}-mac
        PRIVATE
            LegacyWeakReference.h
            LegacyWeakReference.mm)
endif()

if(TR_MACOS_USES_MAVERICKS_STACK_XIBS)
    target_sources(${TR_NAME}-mac
        PRIVATE
            MavericksStackView.h
            MavericksStackView.mm)
endif()

target_compile_definitions(${TR_NAME}-mac
    PRIVATE
        TR_ENABLE_SPARKLE=$<BOOL:${TR_ENABLE_SPARKLE}>
        TR_RAISE_FILE_DESCRIPTOR_LIMIT=$<BOOL:${TR_RAISE_FILE_DESCRIPTOR_LIMIT}>)

if(TR_ENABLE_SPARKLE)
    target_sources(${TR_NAME}-mac
        PRIVATE
            SparkleProxy.mm)
endif()

if(TR_MACOS_TARGET_BEFORE_11_0)
    target_compile_options(${TR_NAME}-mac PRIVATE
        -include ${CMAKE_CURRENT_SOURCE_DIR}/CocoaCompatibility.h
        -Wno-nullability-completeness)
endif()

set(XIB_FILES
    AboutWindow.xib
    BlocklistStatusWindow.xib
    FileRenameSheetController.xib
    InfoFileView.xib
    InfoPeersView.xib
    InfoTrackersView.xib
    InfoWindow.xib
    MessageWindow.xib
    StatusBar.xib
    URLSheetWindow.xib)
if(NOT TR_MACOS_USES_COMPAT_STACK_XIBS)
    list(APPEND XIB_FILES
        FilterBar.xib
        StatsWindow.xib)
endif()

set(RESOURCES
    Defaults.plist
    Credits.rtf
    ../COPYING
    Images/TransmissionDocument.icns)
if(TR_ENABLE_SPARKLE)
    list(APPEND RESOURCES sparkle_dsa_pub.pem)
endif()
source_group(Resources
    FILES ${RESOURCES})

set_source_files_properties(
    ${RESOURCES}
    PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)

set(IMAGESETS
    ActionHover
    CleanupTemplate
    CompleteCheck
    CreateLarge
    DownArrowGroupTemplate
    DownArrowTemplate
    DownloadBadge
    EllipsisTemplate
    Globe
    Magnet
    PauseHover
    PauseOff
    PauseOn
    PinTemplate
    PriorityControlHigh
    PriorityControlLow
    PriorityControlNormal
    PriorityHighTemplate
    PriorityLowTemplate
    PriorityNormalTemplate
    ResumeHover
    ResumeNoWaitHover
    ResumeNoWaitOff
    ResumeNoWaitOn
    ResumeOff
    ResumeOn
    RevealHover
    RevealOff
    RevealOn
    TortoiseTemplate
    UpArrowGroupTemplate
    UpArrowTemplate
    UploadBadge
    YingYangGroupTemplate
    YingYangTemplate)

set(APPICON_NAME AppIcon)

set(IMAGE_ASSETS_DIR Images/Images.xcassets)
set(APPICONSET_DIR "${IMAGE_ASSETS_DIR}/${APPICON_NAME}.appiconset")
set(LEGACY_ICON_ASSETS_DIR Images/LegacyIconAssets)
set(LEGACY_ICON_IMAGESETS
    Bandwidth
    Groups
    InfoActivity
    InfoFiles
    InfoGeneral
    InfoOptions
    InfoPeers
    InfoTracker
    Remote
    ToolbarCreateTemplate
    ToolbarInfoTemplate
    ToolbarOpenTemplate
    ToolbarRemoveTemplate
    Transfers)

set(IMAGE_ASSETS
    ${IMAGE_ASSETS_DIR}/Contents.json
    ${APPICONSET_DIR}/Contents.json)
set(LEGACY_ICON_ASSETS)

foreach(IMG IN LISTS IMAGESETS)
    set(IMG_DIR "${IMAGE_ASSETS_DIR}/${IMG}.imageset")
    list(APPEND IMAGE_ASSETS
        ${IMG_DIR}/${IMG}.png
        ${IMG_DIR}/${IMG}@2x.png
        ${IMG_DIR}/Contents.json)
endforeach()

if(TR_MACOS_DEPLOYMENT_BEFORE_10_14)
    foreach(IMG IN LISTS LEGACY_ICON_IMAGESETS)
        set(IMG_DIR "${LEGACY_ICON_ASSETS_DIR}/${IMG}.imageset")
        list(APPEND LEGACY_ICON_ASSETS
            ${IMG_DIR}/${IMG}.png
            ${IMG_DIR}/${IMG}@2x.png
            ${IMG_DIR}/Contents.json)
    endforeach()
endif()

foreach(SIZE IN ITEMS 16 32 128 256 512)
    list(APPEND IMAGE_ASSETS
        ${APPICONSET_DIR}/icon_${SIZE}x${SIZE}.png
        ${APPICONSET_DIR}/icon_${SIZE}x${SIZE}@2x.png)
endforeach()

set(COMPILED_IMAGE_ASSETS
    "${CMAKE_CURRENT_BINARY_DIR}/${APPICON_NAME}.icns")

set(TR_LEGACY_IMAGE_ASSET_COMMANDS)
if(TR_MACOS_TARGET_BEFORE_11_0)
    foreach(IMG IN LISTS IMAGESETS)
        list(APPEND COMPILED_IMAGE_ASSETS
            "${CMAKE_CURRENT_BINARY_DIR}/${IMG}.png"
            "${CMAKE_CURRENT_BINARY_DIR}/${IMG}@2x.png")
        list(APPEND TR_LEGACY_IMAGE_ASSET_COMMANDS
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/${IMAGE_ASSETS_DIR}/${IMG}.imageset/${IMG}.png"
                "${CMAKE_CURRENT_BINARY_DIR}/${IMG}.png"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/${IMAGE_ASSETS_DIR}/${IMG}.imageset/${IMG}@2x.png"
                "${CMAKE_CURRENT_BINARY_DIR}/${IMG}@2x.png")
    endforeach()
    if(TR_MACOS_DEPLOYMENT_BEFORE_10_14)
        foreach(IMG IN LISTS LEGACY_ICON_IMAGESETS)
            list(APPEND COMPILED_IMAGE_ASSETS
                "${CMAKE_CURRENT_BINARY_DIR}/${IMG}.png"
                "${CMAKE_CURRENT_BINARY_DIR}/${IMG}@2x.png")
            list(APPEND TR_LEGACY_IMAGE_ASSET_COMMANDS
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${CMAKE_CURRENT_SOURCE_DIR}/${LEGACY_ICON_ASSETS_DIR}/${IMG}.imageset/${IMG}.png"
                    "${CMAKE_CURRENT_BINARY_DIR}/${IMG}.png"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${CMAKE_CURRENT_SOURCE_DIR}/${LEGACY_ICON_ASSETS_DIR}/${IMG}.imageset/${IMG}@2x.png"
                    "${CMAKE_CURRENT_BINARY_DIR}/${IMG}@2x.png")
        endforeach()
    endif()
else()
    list(APPEND COMPILED_IMAGE_ASSETS
        "${CMAKE_CURRENT_BINARY_DIR}/Assets.car")
endif()

if(TR_MACOS_USE_SOURCE_IMAGE_ASSETS)
    add_custom_command(
        OUTPUT ${COMPILED_IMAGE_ASSETS}
        COMMAND
            ${SIPS_EXECUTABLE}
            -s format icns
            "${CMAKE_CURRENT_SOURCE_DIR}/${APPICONSET_DIR}/icon_512x512.png"
            --out "${CMAKE_CURRENT_BINARY_DIR}/${APPICON_NAME}.icns"
        ${TR_LEGACY_IMAGE_ASSET_COMMANDS}
        DEPENDS ${IMAGE_ASSETS} ${LEGACY_ICON_ASSETS}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM)
    source_group("Generated Files"
        FILES ${COMPILED_IMAGE_ASSETS})
else()
    add_custom_command(
        OUTPUT
            ${COMPILED_IMAGE_ASSETS}
            ${APPICON_NAME}.Info.plist
        COMMAND
            ${ACTOOL_EXECUTABLE}
            --compile "${CMAKE_CURRENT_BINARY_DIR}"
            --platform macosx
            --minimum-deployment-target ${CMAKE_OSX_DEPLOYMENT_TARGET}
            --app-icon ${APPICON_NAME}
            --output-partial-info-plist "${CMAKE_CURRENT_BINARY_DIR}/${APPICON_NAME}.Info.plist"
            ${IMAGE_ASSETS_DIR}
        ${TR_LEGACY_IMAGE_ASSET_COMMANDS}
        DEPENDS ${IMAGE_ASSETS} ${LEGACY_ICON_ASSETS}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    source_group("Generated Files"
        FILES
            ${COMPILED_IMAGE_ASSETS}
            ${APPICON_NAME}.Info.plist)
endif()

list(APPEND RESOURCES
    ${COMPILED_IMAGE_ASSETS})

set_source_files_properties(
    ${COMPILED_IMAGE_ASSETS}
    PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)

set(LINGUAS
    da
    de
    en
    es
    eu
    fr
    he
    hu
    it
    ja
    nl
    pl
    pt-BR
    pt-PT
    ru
    sv
    tr
    uk
    zh-CN
    zh-TW)

if(ENABLE_NLS)
    set(ENABLED_LINGUAS ${LINGUAS})
else()
    set(ENABLED_LINGUAS en)
endif()

set(BASE_XIB_FILES
    AddMagnetWindow.xib
    AddWindow.xib
    Creator.xib
    GlobalOptionsPopover.xib
    GroupRules.xib
    InfoActivityView.xib
    InfoGeneralView.xib
    InfoOptionsView.xib
    MainMenu.xib
    PrefsWindow.xib)
set(BASE_XIB_SOURCE_FILES ${BASE_XIB_FILES})
if(TR_MACOS_USES_COMPAT_STACK_XIBS)
    list(REMOVE_ITEM BASE_XIB_SOURCE_FILES
        InfoActivityView.xib
        InfoOptionsView.xib
        MainMenu.xib)
endif()
list(TRANSFORM BASE_XIB_FILES
    PREPEND Base.lproj/)
list(TRANSFORM BASE_XIB_SOURCE_FILES
    PREPEND Base.lproj/)

set(LANG_STRINGS_FILES
    InfoPlist.strings
    Localizable.strings)

foreach(LANG ${ENABLED_LINGUAS})
    set(${LANG}_STRINGS_FILES)
    if(NOT LANG STREQUAL "en")
        foreach(F ${BASE_XIB_FILES})
            get_filename_component(F_BASE "${F}" NAME_WE)
            list(APPEND ${LANG}_STRINGS_FILES ${LANG}.lproj/${F_BASE}.strings)
        endforeach()
    endif()
    foreach(F ${LANG_STRINGS_FILES})
        list(APPEND ${LANG}_STRINGS_FILES ${LANG}.lproj/${F})
    endforeach()
    source_group(Resources/${LANG}.lproj
        FILES ${${LANG}_STRINGS_FILES})
endforeach()

foreach(LANG ${ENABLED_LINGUAS})
    list(APPEND RESOURCES ${${LANG}_STRINGS_FILES})
    set(STRINGS_FILES_RESOURCES_DIR Resources)
    if(NOT CMAKE_GENERATOR STREQUAL Xcode)
        string(APPEND STRINGS_FILES_RESOURCES_DIR /${LANG}.lproj)
    endif()
    set_source_files_properties(
        ${${LANG}_STRINGS_FILES}
        PROPERTIES
            MACOSX_PACKAGE_LOCATION ${STRINGS_FILES_RESOURCES_DIR})
endforeach()

target_sources(${TR_NAME}-mac
    PRIVATE
        ${RESOURCES})

if(TR_MACOS_XIB_COMPAT_LEGACY_IBTOOL)
    # Lion's Xcode 4.6 ibtool rejects modern document archives outright, so
    # both 10.6 and 10.7 builds compile the curated SnowLeopardXibs copies.
    set(TR_MACOS_XIB_COMPAT_LEGACY_IBTOOL_FILES
        ${XIB_FILES}
        FilterBar.xib
        StatsWindow.xib)

    foreach(XIB_FILE IN LISTS TR_MACOS_XIB_COMPAT_LEGACY_IBTOOL_FILES)
        get_filename_component(XIB_NAME_WLE "${XIB_FILE}" NAME_WLE)

        tr_wrap_xib(${TR_NAME}-mac
            SnowLeopardXibs/${XIB_FILE}
            "${CMAKE_CURRENT_BINARY_DIR}/${XIB_NAME_WLE}.nib"
            "")
    endforeach()

    foreach(LANG IN LISTS ENABLED_LINGUAS)
        foreach(XIB_FILE IN LISTS BASE_XIB_FILES)
            get_filename_component(XIB_NAME_WLE "${XIB_FILE}" NAME_WLE)
            set(TR_MACOS_LOCALIZED_XIB_STRINGS_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${LANG}.lproj/${XIB_NAME_WLE}.strings")

            if(EXISTS "${TR_MACOS_LOCALIZED_XIB_STRINGS_FILE}")
                tr_wrap_localized_xib(${TR_NAME}-mac
                    SnowLeopardXibs/${XIB_FILE}
                    "${CMAKE_CURRENT_BINARY_DIR}/${LANG}.lproj/${XIB_NAME_WLE}.nib"
                    ${LANG}.lproj
                    "${TR_MACOS_LOCALIZED_XIB_STRINGS_FILE}")
            else()
                tr_wrap_xib(${TR_NAME}-mac
                    SnowLeopardXibs/${XIB_FILE}
                    "${CMAKE_CURRENT_BINARY_DIR}/${LANG}.lproj/${XIB_NAME_WLE}.nib"
                    ${LANG}.lproj)
            endif()
        endforeach()
    endforeach()
else()
    tr_target_xib_files(${TR_NAME}-mac
        ${XIB_FILES}
        ${BASE_XIB_SOURCE_FILES})
endif()

if(TR_MACOS_USES_MAVERICKS_STACK_XIBS)
    # Xcode 6.x's ibtool cannot compile these modern stack-view XIBs, but
    # OS X 10.9 and 10.10 have NSStackView. Use XIB copies that decode as
    # MavericksStackView and then rebuild native NSStackView state at runtime.
    tr_wrap_xib(${TR_NAME}-mac
        MavericksXibs/FilterBar.xib
        "${CMAKE_CURRENT_BINARY_DIR}/FilterBar.nib"
        "")
    tr_wrap_xib(${TR_NAME}-mac
        MavericksXibs/StatsWindow.xib
        "${CMAKE_CURRENT_BINARY_DIR}/StatsWindow.nib"
        "")
    tr_wrap_xib(${TR_NAME}-mac
        MavericksXibs/Base.lproj/InfoActivityView.xib
        "${CMAKE_CURRENT_BINARY_DIR}/Base.lproj/InfoActivityView.nib"
        Base.lproj)
    tr_wrap_xib(${TR_NAME}-mac
        MavericksXibs/Base.lproj/InfoOptionsView.xib
        "${CMAKE_CURRENT_BINARY_DIR}/Base.lproj/InfoOptionsView.nib"
        Base.lproj)
    tr_wrap_xib(${TR_NAME}-mac
        MavericksXibs/Base.lproj/MainMenu.xib
        "${CMAKE_CURRENT_BINARY_DIR}/Base.lproj/MainMenu.nib"
        Base.lproj)
endif()

if(TR_MACOS_XIB_COMPAT_10_8)
    tr_wrap_xib(${TR_NAME}-mac
        MountainLionXibs/FilterBar.xib
        "${CMAKE_CURRENT_BINARY_DIR}/FilterBar.nib"
        "")
    tr_wrap_xib(${TR_NAME}-mac
        MountainLionXibs/StatsWindow.xib
        "${CMAKE_CURRENT_BINARY_DIR}/StatsWindow.nib"
        "")
    tr_wrap_xib(${TR_NAME}-mac
        MountainLionXibs/Base.lproj/InfoActivityView.xib
        "${CMAKE_CURRENT_BINARY_DIR}/Base.lproj/InfoActivityView.nib"
        Base.lproj)
    tr_wrap_xib(${TR_NAME}-mac
        MountainLionXibs/Base.lproj/InfoOptionsView.xib
        "${CMAKE_CURRENT_BINARY_DIR}/Base.lproj/InfoOptionsView.nib"
        Base.lproj)
    tr_wrap_xib(${TR_NAME}-mac
        MountainLionXibs/Base.lproj/MainMenu.xib
        "${CMAKE_CURRENT_BINARY_DIR}/Base.lproj/MainMenu.nib"
        Base.lproj)
endif()

set(SPARKLE_LINK_LIBRARIES)
if(TR_ENABLE_SPARKLE)
    find_library(SPARKLE_FRAMEWORK Sparkle
        PATHS ${CMAKE_CURRENT_SOURCE_DIR}
        NO_DEFAULT_PATHS)
    set(SPARKLE_LINK_LIBRARIES ${SPARKLE_FRAMEWORK} "-weak_framework Sparkle")
endif()

target_link_libraries(${TR_NAME}-mac
    PRIVATE
        ${TR_NAME}
        transmission::fmt-header-only
        vdkqueue
        ${SPARKLE_LINK_LIBRARIES}
        "-framework AppKit"
        "-framework Carbon"
        "-framework Foundation"
        "-framework Quartz"
        "-framework Security")

if(TR_MACOS_DEPLOYMENT_BEFORE_10_7)
    target_link_libraries(${TR_NAME}-mac PRIVATE "-licucore")
endif()

if(NOT TR_MACOS_TARGET_BEFORE_11_0)
    target_link_libraries(${TR_NAME}-mac PRIVATE "-weak_framework UniformTypeIdentifiers")
endif()

if(IS_ABSOLUTE "${CMAKE_OSX_SYSROOT}")
    find_library(USERNOTIFICATIONS_FRAMEWORK UserNotifications
        PATHS "${CMAKE_OSX_SYSROOT}/System/Library/Frameworks"
        NO_DEFAULT_PATH)
else()
    find_library(USERNOTIFICATIONS_FRAMEWORK UserNotifications)
endif()
if(USERNOTIFICATIONS_FRAMEWORK)
    target_link_libraries(${TR_NAME}-mac PRIVATE "-weak_framework UserNotifications")
endif()

if(NOT CMAKE_GENERATOR STREQUAL Xcode AND NOT TR_MACOS_DEPLOYMENT_BEFORE_10_7)
    set(TR_MACOS_CODESIGN_COMMAND ${CODESIGN_EXECUTABLE})
    if(CODESIGN_ALLOCATE_EXECUTABLE)
        set(TR_MACOS_CODESIGN_COMMAND
            ${CMAKE_COMMAND} -E env
                "CODESIGN_ALLOCATE=${CODESIGN_ALLOCATE_EXECUTABLE}"
                ${CODESIGN_EXECUTABLE})
    endif()

    add_custom_command(
        TARGET ${TR_NAME}-mac
        POST_BUILD
        COMMAND ${TR_MACOS_CODESIGN_COMMAND} -s - $<TARGET_BUNDLE_DIR:${TR_NAME}-mac>)
endif()

set_target_properties(
    ${TR_NAME}-mac
    PROPERTIES
        INSTALL_RPATH "@executable_path;@executable_path/../Frameworks"
        MACOSX_BUNDLE_GUI_IDENTIFIER "org.m0k.transmission"
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
        OUTPUT_NAME ${MAC_BUNDLE_NAME})

install(
    TARGETS ${TR_NAME}-mac
    DESTINATION Applications)

install(
    DIRECTORY TransmissionHelp
    DESTINATION Applications/${MAC_BUNDLE_NAME}.app/Contents/Resources)
tr_install_web(Applications/${MAC_BUNDLE_NAME}.app/Contents/Resources)

install(CODE
    "list(APPEND CMAKE_MODULE_PATH \"${PROJECT_SOURCE_DIR}/cmake\")
    include(TrMacros)
    include(GetPrerequisites)
    tr_fixup_bundle_item(
        \"\$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/Applications/${MAC_BUNDLE_NAME}.app\"
        \"Contents/MacOS/${MAC_BUNDLE_NAME}\" \"${CMAKE_CURRENT_SOURCE_DIR}\")")
