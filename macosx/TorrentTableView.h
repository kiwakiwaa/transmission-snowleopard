// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class Torrent;
@class Controller;

extern CGFloat const kGroupSeparatorHeight;

@interface TorrentTableView : NSOutlineView<NSOutlineViewDelegate, NSAnimationDelegate, NSPopoverDelegate, NSMenuItemValidation>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    Controller* _fController;
    NSUserDefaults* _fDefaults;
    NSMutableIndexSet* _fCollapsedGroups;
    NSMenu* _fContextRow;
    NSMenu* _fContextNoRow;
    NSIndexSet* _fSelectedRowIndexes;
    CGFloat _piecesBarPercent;
    NSAnimation* _fPiecesBarAnimation;
    BOOL _fActionPopoverShown;
    NSView* _fPositioningView;
    NSDictionary* _fHoverEventDict;
    NSMutableIndexSet* _fPendingSelectionReloadRows;
}
#endif

- (void)reloadVisibleRows;

- (BOOL)isGroupCollapsed:(NSInteger)value;
- (void)removeCollapsedGroup:(NSInteger)value;
- (void)removeAllCollapsedGroups;
- (void)saveCollapsedGroups;

@property(nonatomic) NSArray* selectedTorrents;

- (NSRect)iconRectForRow:(NSInteger)row;

- (void)copy:(id)sender;
- (void)paste:(id)sender;

- (void)hoverEventBeganForView:(id)view;
- (void)hoverEventEndedForView:(id)view;

- (void)toggleGroupRowRatio;

- (IBAction)toggleControlForTorrent:(id)sender;

- (IBAction)displayTorrentActionPopover:(id)sender;

- (void)togglePiecesBar;
@property(nonatomic, readonly) CGFloat piecesBarPercent;

- (void)selectAndScrollToRow:(NSInteger)row;

@end
