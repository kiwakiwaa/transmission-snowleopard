// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "InfoWindowController.h"
#import "CocoaCompatibility.h"
#import "FileListNode.h"
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_8
#import "BaseFileNameCellView.h"
#endif
#import "FileNameCell.h"
#import "FileOutlineView.h"
#import "FilePriorityCell.h"
#import "FilePriorityCellView.h"
#import "Torrent.h"

@interface FileOutlineView ()

@property(nonatomic) NSInteger hoveredRow;

@end

@implementation FileOutlineView

- (void)awakeFromNib
{
    [super awakeFromNib];

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8
    FileNameCell* nameCell = [[FileNameCell alloc] init];
    [[self tableColumnWithIdentifier:@"Name"] setDataCell:nameCell];

    FilePriorityCell* priorityCell = [[FilePriorityCell alloc] init];
    [[self tableColumnWithIdentifier:@"Priority"] setDataCell:priorityCell];

    self.hoveredRow = -1;
#endif

    self.autoresizesOutlineColumn = NO;
    self.indentationPerLevel = 14.0;
}

- (void)mouseDown:(NSEvent*)event
{
    [self.window makeKeyWindow];
    [super mouseDown:event];
}

- (NSMenu*)menuForEvent:(NSEvent*)event
{
    NSInteger const row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];

    if (row >= 0)
    {
        if (![self isRowSelected:row])
        {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
    else
    {
        [self deselectAll:self];
    }

    return self.menu;
}

- (NSRect)iconRectForRow:(NSInteger)row
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_8
    NSInteger const column = [self columnWithIdentifier:@"Name"];
    if (column < 0)
    {
        return NSZeroRect;
    }

    NSCell* preparedCell = [self preparedCellAtColumn:column row:row];
    if (![preparedCell isKindOfClass:[FileNameCell class]])
    {
        return NSZeroRect;
    }

    FileNameCell* cell = (FileNameCell*)preparedCell;
    NSRect iconRect = [cell imageRectForBounds:[self rectOfRow:row]];
    iconRect.origin.x += self.indentationPerLevel * (CGFloat)([self levelForRow:row] + 1);
    return iconRect;
#else
    NSView* view = [self viewAtColumn:[self columnWithIdentifier:@"Name"] row:row makeIfNecessary:NO];
    if (![view isKindOfClass:[BaseFileNameCellView class]])
    {
        return NSZeroRect;
    }

    BaseFileNameCellView* cellView = (BaseFileNameCellView*)view;
    NSImageView* iconView = [cellView valueForKey:@"iconView"];
    if (!iconView)
    {
        return NSZeroRect;
    }

    NSRect iconRect = [self convertRect:iconView.frame fromView:cellView];
    iconRect.origin.x += self.indentationPerLevel * (CGFloat)([self levelForRow:row] + 1);
    return iconRect;
#endif
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8
- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    for (NSTrackingArea* area in [self.trackingAreas copy])
    {
        if (area.owner == self && area.userInfo[@"Row"])
        {
            [self removeTrackingArea:area];
        }
    }

    NSRange visibleRows = [self rowsInRect:self.visibleRect];
    if (visibleRows.length == 0)
    {
        return;
    }

    NSInteger const column = [self columnWithIdentifier:@"Priority"];
    if (column < 0)
    {
        return;
    }

    NSPoint mouseLocation = [self convertPoint:self.window.mouseLocationOutsideOfEventStream fromView:nil];
    for (NSInteger row = visibleRows.location; (NSUInteger)row < NSMaxRange(visibleRows); row++)
    {
        NSCell* cell = [self preparedCellAtColumn:column row:row];
        if (![cell isKindOfClass:[FilePriorityCell class]])
        {
            continue;
        }

        NSDictionary* userInfo = @{ @"Row" : @(row) };
        [(FilePriorityCell*)cell addTrackingAreasForView:self inRect:[self frameOfCellAtColumn:column row:row] withUserInfo:userInfo
                                           mouseLocation:mouseLocation];
    }
}

- (void)mouseEntered:(NSEvent*)event
{
    NSNumber* row = ((NSDictionary*)event.userData)[@"Row"];
    if (row)
    {
        self.hoveredRow = row.integerValue;
        [self setNeedsDisplayInRect:[self frameOfCellAtColumn:[self columnWithIdentifier:@"Priority"] row:self.hoveredRow]];
    }
}

- (void)mouseExited:(NSEvent*)event
{
    NSNumber* row = ((NSDictionary*)event.userData)[@"Row"];
    if (row)
    {
        [self setNeedsDisplayInRect:[self frameOfCellAtColumn:[self columnWithIdentifier:@"Priority"] row:row.integerValue]];
        self.hoveredRow = -1;
    }
}
#endif

@end
