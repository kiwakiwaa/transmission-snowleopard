// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "TrackerTableView.h"
#import "CocoaCompatibility.h"
#import "Torrent.h"
#import "TrackerNode.h"

@implementation TrackerTableView

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize torrent = _torrent;
@synthesize trackers = _trackers;
#endif

- (void)mouseDown:(NSEvent*)event
{
    [self.window makeKeyWindow];
    [super mouseDown:event];
}

- (void)copy:(id)sender
{
    NSMutableArray* addresses = [NSMutableArray arrayWithCapacity:self.trackers.count];
    NSIndexSet* indexes = self.selectedRowIndexes;
    for (NSUInteger i = indexes.firstIndex; i != NSNotFound; i = [indexes indexGreaterThanIndex:i])
    {
        id item = self.trackers[i];
        if (![item isKindOfClass:[TrackerNode class]])
        {
            for (++i; i < self.trackers.count && [self.trackers[i] isKindOfClass:[TrackerNode class]]; ++i)
            {
                [addresses addObject:((TrackerNode*)self.trackers[i]).fullAnnounceAddress];
            }
            --i;
        }
        else
        {
            [addresses addObject:((TrackerNode*)item).fullAnnounceAddress];
        }
    }

    NSString* text = [addresses componentsJoinedByString:@"\n"];

    TRPasteboardWriteStrings([NSPasteboard generalPasteboard], @[ text ]);
}

- (void)paste:(id)sender
{
    NSAssert(self.torrent != nil, @"no torrent but trying to paste; should not be able to call this method");

    BOOL added = NO;

    NSArray* items = TRPasteboardReadStrings([NSPasteboard generalPasteboard]);
    NSAssert(items != nil, @"no string items to paste; should not be able to call this method");

    for (NSString* pbItem in items)
    {
        for (NSString* item in [pbItem componentsSeparatedByString:@"\n"])
        {
            if ([self.torrent addTrackerToNewTier:item])
            {
                added = YES;
            }
        }
    }

    //none added
    if (!added)
    {
        NSBeep();
    }
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    SEL const action = menuItem.action;

    if (action == @selector(copy:))
    {
        return self.numberOfSelectedRows > 0;
    }

    if (action == @selector(paste:))
    {
        return self.torrent && TRPasteboardCanReadStrings([NSPasteboard generalPasteboard]);
    }

    return YES;
}

@end
