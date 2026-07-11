// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "InfoViewController.h"

@class TrackerCell;
@class TrackerTableView;

@interface InfoTrackersViewController : NSViewController<InfoViewController>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    BOOL _fSet;
    NSMutableArray* _fTrackers;
    IBOutlet TrackerTableView* _fTrackerTable;
    TrackerCell* _fTrackerCell;
    IBOutlet NSSegmentedControl* _fTrackerAddRemoveControl;
}
#endif

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)updateInfo;

- (void)saveViewSize;
- (void)clearView;

- (IBAction)addRemoveTracker:(id)sender;

@end
