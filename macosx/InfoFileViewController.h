// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>
#include <libtransmission/macos-version.h>
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5
#import <Quartz/Quartz.h>
#endif

#import "InfoViewController.h"

@class FileOutlineController;

@interface InfoFileViewController : NSViewController<InfoViewController>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    BOOL _fSet;
    IBOutlet FileOutlineController* _fFileController;
    IBOutlet NSSearchField* _fFileFilterField;
    IBOutlet NSButton* _fCheckAllButton;
    IBOutlet NSButton* _fUncheckAllButton;
}
#endif

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5
@property(nonatomic, readonly) NSArray* quickLookURLs;
@property(nonatomic, readonly) BOOL canQuickLook;
#endif

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)updateInfo;

- (void)saveViewSize;

- (IBAction)setFileFilterText:(id)sender;
- (IBAction)checkAll:(id)sender;
- (IBAction)uncheckAll:(id)sender;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5
- (NSRect)quickLookSourceFrameForPreviewItem:(id<QLPreviewItem>)item;
#endif

@end
