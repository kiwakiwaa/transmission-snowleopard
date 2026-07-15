// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>
#include <libtransmission/macos-version.h>
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5
#import <Quartz/Quartz.h>
#endif

#import "InfoWindow.h"

@class InfoActivityViewController;
@class InfoFileViewController;
@class InfoGeneralViewController;
@class InfoOptionsViewController;
@class InfoPeersViewController;
@class InfoTrackersViewController;
@protocol InfoViewController;
@class Torrent;

@interface InfoWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    CGFloat _fMinWindowWidth;
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
    CGFloat _fLiveResizeTopEdge;
    BOOL _fRestoringLiveResizeTopEdge;
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    BOOL _fUpdatingWindowLayout;
    CGFloat _fLegacyCurrentContentHeight;
    CGFloat _fLegacyInspectorChromeHeight;
    NSMutableDictionary* _fLegacyMinimumWidths;
#endif
    NSViewController<InfoViewController>* _fViewController;
    NSInteger _fCurrentTabTag;
    IBOutlet NSSegmentedControl* _fTabs;
    InfoGeneralViewController* _fGeneralViewController;
    InfoActivityViewController* _fActivityViewController;
    InfoTrackersViewController* _fTrackersViewController;
    InfoPeersViewController* _fPeersViewController;
    InfoFileViewController* _fFileViewController;
    InfoOptionsViewController* _fOptionsViewController;
    IBOutlet NSImageView* _fImageView;
    IBOutlet NSTextField* _fNameField;
    IBOutlet NSTextField* _fBasicInfoField;
    IBOutlet NSTextField* _fNoneSelectedField;
}
#endif

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5
@property(nonatomic, readonly) NSArray* quickLookURLs;
@property(nonatomic, readonly) BOOL canQuickLook;
#endif

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)removeTorrentsFromInfo:(NSArray*)torrents;
- (void)updateInfoStats;
- (void)updateOptions;

- (IBAction)setTab:(id)sender;

- (void)setNextTab;
- (void)setPreviousTab;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5
- (NSRect)quickLookSourceFrameForPreviewItem:(id<QLPreviewItem>)item;
#endif

@end
