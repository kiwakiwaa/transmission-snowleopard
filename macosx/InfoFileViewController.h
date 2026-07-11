// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>
#import <Quartz/Quartz.h>

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

@property(nonatomic, readonly) NSArray* quickLookURLs;
@property(nonatomic, readonly) BOOL canQuickLook;

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)updateInfo;

- (void)saveViewSize;

- (IBAction)setFileFilterText:(id)sender;
- (IBAction)checkAll:(id)sender;
- (IBAction)uncheckAll:(id)sender;

- (NSRect)quickLookSourceFrameForPreviewItem:(id<QLPreviewItem>)item;

@end
