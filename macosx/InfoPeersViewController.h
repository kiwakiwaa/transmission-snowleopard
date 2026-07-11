// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "InfoViewController.h"

@class NSLayoutConstraint;
@class WebSeedTableView;

@interface InfoPeersViewController : NSViewController<InfoViewController>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    BOOL _fSet;
    NSMutableArray* _fPeers;
    NSMutableArray* _fWebSeeds;
    IBOutlet NSTableView* _fPeerTable;
    IBOutlet WebSeedTableView* _fWebSeedTable;
    IBOutlet NSTextField* _fConnectedPeersField;
    CGFloat _fViewTopMargin;
    IBOutlet NSLayoutConstraint* _fWebSeedTableTopConstraint;
}
#endif

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)updateInfo;

- (void)saveViewSize;
- (void)clearView;

@end
