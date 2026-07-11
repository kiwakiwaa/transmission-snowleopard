// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "PortChecker.h"
#import <AppKit/AppKit.h>

#include <libtransmission/transmission.h>

@class DefaultAppHelper;

@interface PrefsController : NSWindowController<NSToolbarDelegate, PortCheckerDelegate>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    tr_session* _fHandle;
    NSUserDefaults* _fDefaults;
    BOOL _fHasLoaded;
    NSView* _fGeneralView;
    NSView* _fTransfersView;
    NSView* _fBandwidthView;
    NSView* _fPeersView;
    NSView* _fNetworkView;
    NSView* _fRemoteView;
    NSView* _fGroupsView;
    NSString* _fInitialString;
    NSButton* _fSystemPreferencesButton;
    NSButton* _fSetDefaultForMagnetButton;
    NSButton* _fSetDefaultForTorrentButton;
    NSTextField* _fCheckForUpdatesLabel;
    NSButton* _fCheckForUpdatesButton;
    NSButton* _fCheckForUpdatesBetaButton;
    NSPopUpButton* _fFolderPopUp;
    NSPopUpButton* _fIncompleteFolderPopUp;
    NSPopUpButton* _fImportFolderPopUp;
    NSPopUpButton* _fDoneScriptPopUp;
    NSButton* _fShowMagnetAddWindowCheck;
    NSTextField* _fRatioStopField;
    NSTextField* _fIdleStopField;
    NSTextField* _fQueueDownloadField;
    NSTextField* _fQueueSeedField;
    NSTextField* _fStalledField;
    NSTextField* _fUploadField;
    NSTextField* _fDownloadField;
    NSTextField* _fSpeedLimitUploadField;
    NSTextField* _fSpeedLimitDownloadField;
    NSPopUpButton* _fAutoSpeedDayTypePopUp;
    NSTextField* _fPeersGlobalField;
    NSTextField* _fPeersTorrentField;
    NSTextField* _fBlocklistURLField;
    NSTextField* _fBlocklistMessageField;
    NSTextField* _fBlocklistDateField;
    NSButton* _fBlocklistButton;
    PortChecker* _fPortChecker;
    NSTextField* _fPortField;
    NSTextField* _fPortStatusField;
    NSButton* _fNatCheck;
    NSImageView* _fPortStatusImage;
    NSProgressIndicator* _fPortStatusProgress;
    NSTimer* _fPortStatusTimer;
    int _fPeerPort;
    int _fNatStatus;
    NSTextField* _fRPCPortField;
    NSTextField* _fRPCPasswordField;
    NSTableView* _fRPCWhitelistTable;
    NSMutableArray* _fRPCWhitelistArray;
    NSSegmentedControl* _fRPCAddRemoveControl;
    NSString* _fRPCPassword;
    DefaultAppHelper* _fDefaultAppHelper;
}
#endif

@property(nonatomic, readonly) NSArray* sounds;

/// - returns: number of minutes
+ (int)dateToTimeSum:(NSDate*)date;

- (instancetype)initWithHandle:(tr_session*)handle;

- (void)rpcUpdatePrefs;

@end
