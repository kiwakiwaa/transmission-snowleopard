// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "CocoaCompatibility.h"

#import "TorrentTableView.h"
#import "Controller.h"
#import "FileListNode.h"
#import "InfoOptionsViewController.h"
#import "LegacyArchiving.h"
#import "NSStringAdditions.h"
#import "Torrent.h"
#import "TorrentCell.h"
#import "SmallTorrentCell.h"
#import "GroupCell.h"
#import "TorrentGroup.h"
#import "GroupsController.h"
#import "NSImageAdditions.h"
#import "TorrentCellActionButton.h"
#import "TorrentCellControlButton.h"
#import "TorrentCellRevealButton.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
#import "ProgressBarView.h"

@interface LegacyTorrentTableCell : NSCell
@property(nonatomic, TR_OBJC_WEAK) TorrentTableView* tableView;
@property(nonatomic, strong) id legacyObjectValue;
@end

@implementation LegacyTorrentTableCell

static CGFloat const kLegacyGroupDisclosureWidth = 18.0;
static CGFloat const kLegacyGroupStatusWidth = 170.0;

- (instancetype)init
{
    if ((self = [super init]))
    {
        self.lineBreakMode = NSLineBreakByTruncatingMiddle;
    }
    return self;
}

- (void)setObjectValue:(id)objectValue
{
    self.legacyObjectValue = objectValue;
}

- (id)objectValue
{
    return self.legacyObjectValue;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
    id item = self.objectValue;
    NSInteger row = [(NSTableView*)controlView rowAtPoint:NSMakePoint(NSMinX(cellFrame) + 1.0, NSMidY(cellFrame))];
    BOOL selected = row >= 0 && [(NSTableView*)controlView isRowSelected:row];

    if (selected)
    {
        [[NSColor alternateSelectedControlColor] setFill];
    }
    else
    {
        NSColor* color = (row % 2) == 0 ? [NSColor colorWithCalibratedWhite:0.985 alpha:1.0] :
                                          [NSColor colorWithCalibratedWhite:0.955 alpha:1.0];
        [color setFill];
    }
    NSRectFill(cellFrame);

    [[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] setStroke];
    NSBezierPath* line = [NSBezierPath bezierPath];
    [line moveToPoint:NSMakePoint(NSMinX(cellFrame), NSMaxY(cellFrame) - 0.5)];
    [line lineToPoint:NSMakePoint(NSMaxX(cellFrame), NSMaxY(cellFrame) - 0.5)];
    [line stroke];

    NSDictionary* titleAttrs = @{
        NSFontAttributeName : [NSFont boldSystemFontOfSize:[NSFont systemFontSize]],
        NSForegroundColorAttributeName : selected ? NSColor.whiteColor : NSColor.controlTextColor,
    };
    NSDictionary* detailAttrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:10.0],
        NSForegroundColorAttributeName : selected ? NSColor.whiteColor : NSColor.disabledControlTextColor,
    };

    if ([item isKindOfClass:[Torrent class]])
    {
        Torrent* torrent = (Torrent*)item;
        NSInteger const groupValue = torrent.groupValue;
        if (groupValue != -1 && ![NSUserDefaults.standardUserDefaults boolForKey:@"SortByGroup"])
        {
            [[NSImage discIconWithColor:[GroupsController.groups colorForIndex:groupValue]
                            insetFactor:0] drawInRect:NSMakeRect(NSMinX(cellFrame) + 2.0, NSMinY(cellFrame) + 26.0, 10.0, 10.0)
                                             fromRect:NSZeroRect
                                            operation:NSCompositingOperationSourceOver
                                             fraction:1.0
                                       respectFlipped:YES
                                                hints:nil];
        }

        NSImage* icon = torrent.anyErrorOrWarning ? [NSImage imageNamed:NSImageNameCaution] : torrent.icon;
        [icon drawInRect:NSMakeRect(NSMinX(cellFrame) + 13.0, NSMinY(cellFrame) + 13.0, 36.0, 36.0) fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0
            respectFlipped:YES
                     hints:nil];

        CGFloat const left = NSMinX(cellFrame) + 65.0;
        CGFloat const width = MAX(80.0, NSWidth(cellFrame) - 90.0);
        [torrent.name drawInRect:NSMakeRect(left, NSMinY(cellFrame) + 3.0, width, 16.0) withAttributes:titleAttrs];
        [torrent.progressString drawInRect:NSMakeRect(left - 2.0, NSMinY(cellFrame) + 21.0, width + 4.0, 13.0)
                            withAttributes:detailAttrs];
        [ProgressBarView.sharedInstance drawBarInRect:NSMakeRect(left, NSMinY(cellFrame) + 36.0, width, 14.0) forTableView:self.tableView
                                          withTorrent:torrent];
        [torrent.statusString drawInRect:NSMakeRect(left - 2.0, NSMinY(cellFrame) + 50.0, width + 4.0, 13.0) withAttributes:detailAttrs];
    }
    else if ([item isKindOfClass:[TorrentGroup class]])
    {
        TorrentGroup* group = (TorrentGroup*)item;
        NSInteger groupIndex = group.groupIndex;
        BOOL expanded = self.tableView == nil || [self.tableView isItemExpanded:group];

        [[NSColor colorWithCalibratedWhite:selected ? 1.0 : 0.35 alpha:1.0] setFill];
        NSBezierPath* disclosure = [NSBezierPath bezierPath];
        CGFloat midY = NSMidY(cellFrame);
        CGFloat minX = NSMinX(cellFrame) + 7.0;
        if (expanded)
        {
            [disclosure moveToPoint:NSMakePoint(minX, midY - 3.0)];
            [disclosure lineToPoint:NSMakePoint(minX + 8.0, midY - 3.0)];
            [disclosure lineToPoint:NSMakePoint(minX + 4.0, midY + 3.0)];
        }
        else
        {
            [disclosure moveToPoint:NSMakePoint(minX + 2.0, midY - 5.0)];
            [disclosure lineToPoint:NSMakePoint(minX + 2.0, midY + 5.0)];
            [disclosure lineToPoint:NSMakePoint(minX + 8.0, midY)];
        }
        [disclosure closePath];
        [disclosure fill];

        NSColor* groupColor = groupIndex != -1 ? [GroupsController.groups colorForIndex:groupIndex] :
                                                 [NSColor colorWithCalibratedWhite:1.0 alpha:0.0];
        [[NSImage discIconWithColor:groupColor insetFactor:0]
                drawInRect:NSMakeRect(NSMinX(cellFrame) + kLegacyGroupDisclosureWidth + 3.0, NSMinY(cellFrame) + 3.0, 12.0, 12.0)
                  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0
            respectFlipped:YES
                     hints:nil];

        NSString* groupName = groupIndex != -1 ? [GroupsController.groups nameForIndex:groupIndex] :
                                                 NSLocalizedString(@"No Group", "Group table row");
        NSString* title = [NSString localizedStringWithFormat:@"%@ (%lu)", groupName, group.torrents.count];
        NSDictionary* groupAttrs = @{
            NSFontAttributeName : [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]],
            NSForegroundColorAttributeName : selected ? NSColor.whiteColor : NSColor.disabledControlTextColor,
        };
        [title drawInRect:NSMakeRect(
                              NSMinX(cellFrame) + kLegacyGroupDisclosureWidth + 20.0,
                              NSMinY(cellFrame) + 2.0,
                              MAX(80.0, NSWidth(cellFrame) - kLegacyGroupStatusWidth - 45.0),
                              14.0)
            withAttributes:groupAttrs];

        BOOL displayGroupRowRatio = [NSUserDefaults.standardUserDefaults boolForKey:@"DisplayGroupRowRatio"];
        NSString* rightText = displayGroupRowRatio ? [NSString stringForRatio:group.ratio] : [NSString stringForSpeed:group.uploadRate];
        [[NSString stringForSpeed:group.downloadRate] drawInRect:NSMakeRect(NSMaxX(cellFrame) - 165.0, NSMinY(cellFrame) + 2.0, 78.0, 14.0)
                                                  withAttributes:detailAttrs];
        [rightText drawInRect:NSMakeRect(NSMaxX(cellFrame) - 82.0, NSMinY(cellFrame) + 2.0, 76.0, 14.0) withAttributes:detailAttrs];
    }
}

@end
#endif

CGFloat const kGroupSeparatorHeight = 18.0;

static NSInteger const kMaxGroup = 999999;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
static CGFloat const kErrorImageSize = 20.0;
#endif

static NSTimeInterval const kToggleProgressSeconds = 0.175;

@interface NSIndexSet (Transmission)
- (NSIndexSet*)symmetricDifference:(NSIndexSet*)otherSet;
@end

@implementation NSIndexSet (Transmission)

- (NSIndexSet*)symmetricDifference:(NSIndexSet*)otherSet
{
    NSMutableIndexSet* result = [self mutableCopy];
    [result addIndexes:otherSet];

    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL*) {
        if ([otherSet containsIndex:idx])
        {
            [result removeIndex:idx];
        }
    }];

    return [result copy];
}

@end

@interface TorrentTableView ()

@property(nonatomic) IBOutlet Controller* fController;

@property(nonatomic, readonly) NSUserDefaults* fDefaults;

@property(nonatomic, readonly) NSMutableIndexSet* fCollapsedGroups;

@property(nonatomic) IBOutlet NSMenu* fContextRow;
@property(nonatomic) IBOutlet NSMenu* fContextNoRow;

@property(nonatomic) NSIndexSet* fSelectedRowIndexes;

@property(nonatomic) CGFloat piecesBarPercent;
@property(nonatomic) NSAnimation* fPiecesBarAnimation;

@property(nonatomic) BOOL fActionPopoverShown;
@property(nonatomic) NSView* fPositioningView;

@property(nonatomic) NSDictionary* fHoverEventDict;

@property(nonatomic) NSMutableIndexSet* fPendingSelectionReloadRows;

@end

@implementation TorrentTableView

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (void)configureLegacyTorrentColumn
{
    NSTableColumn* torrentColumn = [self tableColumnWithIdentifier:@"Torrent"];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
    // Snow's main XIB currently uses "Torrent"; these fallbacks keep older or edited legacy XIBs cell-renderable.
    if (torrentColumn == nil)
    {
        torrentColumn = [self tableColumnWithIdentifier:@"Group"];
        torrentColumn.identifier = @"Torrent";
    }
    if (torrentColumn == nil && self.tableColumns.count > 0)
    {
        torrentColumn = [self.tableColumns objectAtIndex:0];
        torrentColumn.identifier = @"Torrent";
    }
#endif
    if (torrentColumn == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
    self.outlineTableColumn = torrentColumn;

    NSArray* columns = [self.tableColumns copy];
    for (NSTableColumn* column in columns)
    {
        if (column != torrentColumn)
        {
            [self removeTableColumn:column];
        }
    }
#endif

    LegacyTorrentTableCell* cell = [[LegacyTorrentTableCell alloc] init];
    cell.tableView = self;
    [torrentColumn setDataCell:cell];
}
#endif

- (instancetype)initWithCoder:(NSCoder*)decoder
{
    if ((self = [super initWithCoder:decoder]))
    {
        _fDefaults = NSUserDefaults.standardUserDefaults;

        NSData* groupData;
        if ((groupData = [_fDefaults dataForKey:@"CollapsedGroupIndexes"]))
        {
            _fCollapsedGroups = [TRUnarchiveObjectFromData(groupData, [NSSet setWithObject:NSMutableIndexSet.class]) mutableCopy];
        }
        else if ((groupData = [_fDefaults dataForKey:@"CollapsedGroups"])) //handle old groups
        {
            _fCollapsedGroups = [TRUnarchiveLegacyObjectFromData(groupData) mutableCopy];
            [_fDefaults removeObjectForKey:@"CollapsedGroups"];
            [self saveCollapsedGroups];
        }
        if (_fCollapsedGroups == nil)
        {
            _fCollapsedGroups = [[NSMutableIndexSet alloc] init];
        }

        _fActionPopoverShown = NO;

        self.delegate = self;
        self.indentationPerLevel = 0;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        [self configureLegacyTorrentColumn];
#endif

        _piecesBarPercent = [_fDefaults boolForKey:@"PiecesBar"] ? 1.0 : 0.0;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_11 && !TR_MACOS_SDK_BEFORE_10_11
        self.style = NSTableViewStyleFullWidth;
#endif
    }

    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9 && TR_MACOS_DEPLOYMENT_BEFORE_10_7
    [self configureLegacyTorrentColumn];
#endif
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshTorrentTable) name:@"RefreshTorrentTable"
                                             object:nil];
}

- (void)refreshTorrentTable
{
    self.needsDisplay = YES;
}

//make sure we don't lose selection on manual reloads
- (void)reloadData
{
    NSMutableArray* selectedItems = [NSMutableArray arrayWithCapacity:self.selectedRowIndexes.count];
    [self.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL*) {
        id item = [self itemAtRow:row];
        if (item != nil)
        {
            [selectedItems addObject:item];
        }
    }];

    [super reloadData];

    NSMutableIndexSet* selectedRows = [NSMutableIndexSet indexSet];
    for (id item in selectedItems)
    {
        NSInteger row = [self rowForItem:item];
        if (row >= 0)
        {
            [selectedRows addIndex:row];
        }
    }
    [self selectRowIndexes:selectedRows byExtendingSelection:NO];
}

- (void)reloadVisibleRows
{
    NSRect visibleRect = self.visibleRect;
    NSRange range = [self rowsInRect:visibleRect];

    //since we use floating group rows, we need some magic to find visible group rows
    if ([self.fDefaults boolForKey:@"SortByGroup"])
    {
        NSInteger location = range.location;
        NSInteger length = range.length;
        NSRange fullRange = NSMakeRange(0, length + location);
        NSIndexSet* fullIndexSet = [NSIndexSet indexSetWithIndexesInRange:fullRange];
        NSMutableIndexSet* visibleIndexSet = [[NSMutableIndexSet alloc] init];

        [fullIndexSet enumerateIndexesUsingBlock:^(NSUInteger row, BOOL*) {
            id rowItem = [self itemAtRow:row];
            if ([rowItem isKindOfClass:[TorrentGroup class]])
            {
                [visibleIndexSet addIndex:row];
            }
            else if (NSIntersectsRect(visibleRect, [self rectOfRow:row]))
            {
                [visibleIndexSet addIndex:row];
            }
        }];

        [self reloadDataForRowIndexes:visibleIndexSet columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
    else
    {
        [self reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:range] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}

- (void)reloadDataForRowIndexes:(NSIndexSet*)rowIndexes columnIndexes:(NSIndexSet*)columnIndexes
{
    [super reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    [self setNeedsDisplay:YES];
#else

    //redraw fControlButton
    BOOL minimal = [self.fDefaults boolForKey:@"SmallView"];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL*) {
        id rowItem = [self itemAtRow:row];
        if (![rowItem isKindOfClass:[TorrentGroup class]])
        {
            if (minimal)
            {
                SmallTorrentCell* smallCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
                [(TorrentCellControlButton*)smallCell.fControlButton resetImage];
            }
            else
            {
                TorrentCell* torrentCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
                [(TorrentCellControlButton*)torrentCell.fControlButton resetImage];
            }
        }
    }];
#endif
}

- (BOOL)usesAlternatingRowBackgroundColors
{
    return ![self.fDefaults boolForKey:@"SmallView"];
}

- (BOOL)isGroupCollapsed:(NSInteger)value
{
    if (value == -1)
    {
        value = kMaxGroup;
    }

    return [self.fCollapsedGroups containsIndex:value];
}

- (void)removeCollapsedGroup:(NSInteger)value
{
    if (value == -1)
    {
        value = kMaxGroup;
    }

    [self.fCollapsedGroups removeIndex:value];
}

- (void)removeAllCollapsedGroups
{
    [self.fCollapsedGroups removeAllIndexes];
}

- (void)saveCollapsedGroups
{
    [self.fDefaults setObject:TRArchivedDataForObject(self.fCollapsedGroups) forKey:@"CollapsedGroupIndexes"];
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isGroupItem:(id)item
{
    // We are implementing our own group styling.
    // Apple's default group styling conflicts with this.
    return NO;
}

- (CGFloat)outlineView:(NSOutlineView*)outlineView heightOfRowByItem:(id)item
{
    return [item isKindOfClass:[Torrent class]] ? self.rowHeight : kGroupSeparatorHeight;
}

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (NSView*)outlineView:(NSOutlineView*)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    if ([item isKindOfClass:[Torrent class]])
    {
        Torrent* torrent = (Torrent*)item;
        BOOL const minimal = [self.fDefaults boolForKey:@"SmallView"];
        BOOL const error = torrent.anyErrorOrWarning;

        TorrentCell* torrentCell;
        if (minimal)
        {
            torrentCell = [outlineView makeViewWithIdentifier:@"SmallTorrentCell" owner:self];

            // set torrent icon or error badge
            torrentCell.fIconView.image = error ? [NSImage imageNamed:NSImageNameCaution] : torrent.icon;

            // set torrent status
            torrentCell.fTorrentStatusField.stringValue = [self.fDefaults boolForKey:@"DisplaySmallStatusRegular"] ?
                torrent.shortStatusString :
                torrent.remainingTimeString;

            if (self.fHoverEventDict)
            {
                NSInteger row = [self rowForItem:item];
                NSInteger hoverRow = [self.fHoverEventDict[@"row"] integerValue];

                if (row == hoverRow)
                {
                    torrentCell.fTorrentStatusField.hidden = YES;
                    torrentCell.fControlButton.hidden = NO;
                    torrentCell.fRevealButton.hidden = NO;
                }
            }
            else
            {
                torrentCell.fTorrentStatusField.hidden = NO;
                torrentCell.fControlButton.hidden = YES;
                torrentCell.fRevealButton.hidden = YES;
            }
        }
        else
        {
            torrentCell = [outlineView makeViewWithIdentifier:@"TorrentCell" owner:self];
            torrentCell.fTorrentProgressField.stringValue = torrent.progressString;

            // set torrent icon and error badge
            NSImage* fileImage = torrent.icon;
            if (error)
            {
                NSRect frame = torrentCell.fIconView.frame;
                NSImage* resultImage = [[NSImage alloc] initWithSize:NSMakeSize(frame.size.height, frame.size.width)];
                [resultImage lockFocus];

                // draw fileImage
                [fileImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

                // overlay error badge
                NSImage* errorImage = [NSImage imageNamed:NSImageNameCaution];
                NSRect const errorRect = NSMakeRect(frame.origin.x, 0, kErrorImageSize, kErrorImageSize);
                [errorImage drawInRect:errorRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0
                        respectFlipped:YES
                                 hints:nil];

                [resultImage unlockFocus];

                torrentCell.fIconView.image = resultImage;
            }
            else
            {
                torrentCell.fIconView.image = fileImage;
            }

            // set torrent status
            NSString* status;
            if (self.fHoverEventDict)
            {
                NSInteger row = [self rowForItem:item];
                NSInteger hoverRow = [self.fHoverEventDict[@"row"] integerValue];

                if (row == hoverRow)
                {
                    status = self.fHoverEventDict[@"string"];
                }
            }
            torrentCell.fTorrentStatusField.stringValue = status ?: torrent.statusString;
        }

        torrentCell.fTorrentTableView = self;

        // set this so that we can draw bar in torrentCell drawRect
        torrentCell.objectValue = torrent;

        torrentCell.fTorrentTitleField.stringValue = torrent.name;

        torrentCell.fActionButton.action = @selector(displayTorrentActionPopover:);

        NSInteger const groupValue = torrent.groupValue;
        NSImage* groupImage;
        if (groupValue != -1)
        {
            if (![self.fDefaults boolForKey:@"SortByGroup"])
            {
                NSColor* groupColor = [GroupsController.groups colorForIndex:groupValue];
                groupImage = [NSImage discIconWithColor:groupColor insetFactor:0];
            }
        }

        torrentCell.fGroupIndicatorView.image = groupImage;

        torrentCell.fControlButton.action = @selector(toggleControlForTorrent:);
        torrentCell.fRevealButton.action = @selector(revealTorrentFile:);

        // redraw buttons
        torrentCell.fControlButton.needsDisplay = YES;
        torrentCell.fRevealButton.needsDisplay = YES;

        return torrentCell;
    }
    else
    {
        TorrentGroup* group = (TorrentGroup*)item;
        GroupCell* groupCell = [outlineView makeViewWithIdentifier:@"GroupCell" owner:self];

        NSInteger groupIndex = group.groupIndex;

        NSColor* groupColor = groupIndex != -1 ? [GroupsController.groups colorForIndex:groupIndex] :
                                                 [NSColor colorWithCalibratedWhite:1.0 alpha:0];
        groupCell.fGroupIndicatorView.image = [NSImage discIconWithColor:groupColor insetFactor:0];

        NSString* groupName = groupIndex != -1 ? [GroupsController.groups nameForIndex:groupIndex] :
                                                 NSLocalizedString(@"No Group", "Group table row");

        groupCell.fGroupTitleField.stringValue = groupName;

        groupCell.fGroupDownloadField.stringValue = [NSString stringForSpeed:group.downloadRate];
        groupCell.fGroupDownloadView.image = [NSImage imageNamed:@"DownArrowGroupTemplate"];

        NSString* tooltipDownload = NSLocalizedString(@"Download speed", "Torrent table -> group row -> tooltip");
        groupCell.fGroupDownloadField.toolTip = tooltipDownload;
        groupCell.fGroupDownloadView.toolTip = tooltipDownload;

        BOOL displayGroupRowRatio = [self.fDefaults boolForKey:@"DisplayGroupRowRatio"];
        groupCell.fGroupDownloadField.hidden = displayGroupRowRatio;
        groupCell.fGroupDownloadView.hidden = displayGroupRowRatio;

        if (displayGroupRowRatio)
        {
            groupCell.fGroupUploadAndRatioView.image = [NSImage imageNamed:@"YingYangGroupTemplate"];
            groupCell.fGroupUploadAndRatioView.image.accessibilityDescription = NSLocalizedString(@"Ratio", "Torrent -> status image");

            groupCell.fGroupUploadAndRatioField.stringValue = [NSString stringForRatio:group.ratio];

            NSString* tooltipRatio = NSLocalizedString(@"Ratio", "Torrent table -> group row -> tooltip");
            groupCell.fGroupUploadAndRatioField.toolTip = tooltipRatio;
            groupCell.fGroupUploadAndRatioView.toolTip = tooltipRatio;
        }
        else
        {
            groupCell.fGroupUploadAndRatioView.image = [NSImage imageNamed:@"UpArrowGroupTemplate"];
            groupCell.fGroupUploadAndRatioView.image.accessibilityDescription = NSLocalizedString(@"UL", "Torrent -> status image");

            groupCell.fGroupUploadAndRatioField.stringValue = [NSString stringForSpeed:group.uploadRate];

            NSString* tooltipUpload = NSLocalizedString(@"Upload speed", "Torrent table -> group row -> tooltip");
            groupCell.fGroupUploadAndRatioField.toolTip = tooltipUpload;
            groupCell.fGroupUploadAndRatioView.toolTip = tooltipUpload;
        }

        NSString* tooltipGroup;
        NSUInteger count = group.torrents.count;
        if (count == 1)
        {
            tooltipGroup = NSLocalizedString(@"1 transfer", "Torrent table -> group row -> tooltip");
        }
        else
        {
            tooltipGroup = NSLocalizedString(@"%lu transfers", "Torrent table -> group row -> tooltip");
            tooltipGroup = [NSString localizedStringWithFormat:tooltipGroup, count];
        }
        groupCell.toolTip = tooltipGroup;

        return groupCell;
    }
    return nil;
}

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row
{
    return NSZeroRect;
}
#endif

- (NSString*)outlineView:(NSOutlineView*)outlineView typeSelectStringForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    if ([item isKindOfClass:[Torrent class]])
    {
        return ((Torrent*)item).name;
    }
    else
    {
        return [self.dataSource outlineView:outlineView objectValueForTableColumn:[self tableColumnWithIdentifier:@"Group"]
                                     byItem:item];
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification*)notification
{
    NSIndexSet* oldSelection = self.fSelectedRowIndexes ?: [NSIndexSet indexSet];
    NSIndexSet* newSelection = self.selectedRowIndexes;
    self.fSelectedRowIndexes = newSelection;

    NSIndexSet* changedRows = [oldSelection symmetricDifference:newSelection];
    if (changedRows.count > 0)
    {
        if (!self.fPendingSelectionReloadRows)
        {
            self.fPendingSelectionReloadRows = [[NSMutableIndexSet alloc] init];
            [self performSelector:@selector(flushSelectionReload) withObject:nil afterDelay:0 inModes:@[ NSRunLoopCommonModes ]];
        }

        [self.fPendingSelectionReloadRows addIndexes:changedRows];
    }
}

- (void)flushSelectionReload
{
    NSMutableIndexSet* rows = self.fPendingSelectionReloadRows;
    self.fPendingSelectionReloadRows = nil;

    NSInteger const numberOfRows = self.numberOfRows;
    [rows removeIndexesInRange:NSMakeRange(numberOfRows, NSIntegerMax - numberOfRows)];
    if (rows.count > 0)
    {
        [self reloadDataForRowIndexes:rows columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}

- (void)outlineViewItemDidExpand:(NSNotification*)notification
{
    TorrentGroup* group = notification.userInfo[@"NSObject"];
    NSInteger value = group.groupIndex;
    if (value < 0)
    {
        value = kMaxGroup;
    }

    if ([self.fCollapsedGroups containsIndex:value])
    {
        [self.fCollapsedGroups removeIndex:value];
        [NSNotificationCenter.defaultCenter postNotificationName:@"OutlineExpandCollapse" object:self];
    }
}

- (void)outlineViewItemDidCollapse:(NSNotification*)notification
{
    TorrentGroup* group = notification.userInfo[@"NSObject"];
    NSInteger value = group.groupIndex;
    if (value < 0)
    {
        value = kMaxGroup;
    }

    [self.fCollapsedGroups addIndex:value];
    [NSNotificationCenter.defaultCenter postNotificationName:@"OutlineExpandCollapse" object:self];
}

- (void)mouseDown:(NSEvent*)event
{
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger const row = [self rowAtPoint:point];
    id item = row >= 0 ? [self itemAtRow:row] : nil;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    if (event.clickCount == 1 && [item isKindOfClass:[TorrentGroup class]])
    {
        if ([self pointInLegacyGroupDisclosureRect:point])
        {
            [self isItemExpanded:item] ? [self collapseItem:item] : [self expandItem:item];
            return;
        }
        if ([self pointInGroupStatusRect:point])
        {
            [self toggleGroupRowRatio];
            return;
        }
    }
#endif

    [super mouseDown:event];

    if (event.clickCount == 2) //double click
    {
        if (!item || [item isKindOfClass:[Torrent class]])
        {
            [self.fController showInfo:nil];
        }
        else
        {
            if ([self isItemExpanded:item])
            {
                [self collapseItem:item];
            }
            else
            {
                [self expandItem:item];
            }
        }
    }
    else if ([self pointInGroupStatusRect:point])
    {
        //we check for this here rather than in the GroupCell
        //as using floating group rows causes all sorts of weirdness...
        [self toggleGroupRowRatio];
    }
}

- (NSArray*)selectedTorrents
{
    NSIndexSet* selectedIndexes = self.selectedRowIndexes;
    NSMutableArray* torrents = [NSMutableArray arrayWithCapacity:selectedIndexes.count]; //take a shot at guessing capacity

    for (NSUInteger i = selectedIndexes.firstIndex; i != NSNotFound; i = [selectedIndexes indexGreaterThanIndex:i])
    {
        id item = [self itemAtRow:i];
        if ([item isKindOfClass:[Torrent class]])
        {
            [torrents addObject:item];
        }
        else
        {
            NSArray* groupTorrents = ((TorrentGroup*)item).torrents;
            [torrents addObjectsFromArray:groupTorrents];
            if ([self isItemExpanded:item])
            {
                i += groupTorrents.count;
            }
        }
    }

    return torrents;
}

- (void)setSelectedTorrents:(NSArray*)selectedTorrents
{
    NSMutableIndexSet* selectedIndexes = [NSMutableIndexSet new];
    for (Torrent* i in selectedTorrents)
    {
        NSInteger row = [self rowForItem:i];
        if (row >= 0)
        {
            [selectedIndexes addIndex:row];
        }
    }
    [self selectRowIndexes:selectedIndexes byExtendingSelection:NO];
}

- (NSMenu*)menuForEvent:(NSEvent*)event
{
    NSInteger row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (row >= 0)
    {
        if (![self isRowSelected:row])
        {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
        return self.fContextRow;
    }
    else
    {
        [self deselectAll:self];
        return self.fContextNoRow;
    }
}

//make sure that the pause buttons become orange when holding down the option key
- (void)flagsChanged:(NSEvent*)event
{
    [self display];
    [super flagsChanged:event];
}

//option-command-f will focus the filter bar's search field
- (void)keyDown:(NSEvent*)event
{
    unichar const firstChar = [event.charactersIgnoringModifiers characterAtIndex:0];

    if (firstChar == 'f' && [event modifierFlags] & NSEventModifierFlagOption && [event modifierFlags] & NSEventModifierFlagCommand)
    {
        [self.fController focusFilterField];
    }
    else if (firstChar == ' ')
    {
        [self.fController toggleQuickLook:nil];
    }
    else if (event.keyCode == 53) //esc key
    {
        [self deselectAll:nil];
    }
    else
    {
        [super keyDown:event];
    }
}

- (NSRect)iconRectForRow:(NSInteger)row
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSRect rowRect = [self rectOfRow:row];
    return NSMakeRect(NSMinX(rowRect) + 13.0, NSMinY(rowRect) + 13.0, 36.0, 36.0);
#else
    BOOL minimal = [self.fDefaults boolForKey:@"SmallView"];
    NSRect rect;

    if (minimal)
    {
        SmallTorrentCell* smallCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
        rect = smallCell.fActionButton.frame;
    }
    else
    {
        TorrentCell* torrentCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
        rect = torrentCell.fIconView.frame;
    }

    NSRect rowRect = [self rectOfRow:row];
    rect.origin.y += rowRect.origin.y;
    rect.origin.x += self.intercellSpacing.width;
    return rect;
#endif
}

- (BOOL)acceptsFirstResponder
{
    // add support to `copy:`
    return YES;
}

- (void)copy:(id)sender
{
    NSArray* selectedTorrents = self.selectedTorrents;
    if (selectedTorrents.count == 0)
    {
        return;
    }
    NSPasteboard* pasteBoard = NSPasteboard.generalPasteboard;
    NSString* links = [[selectedTorrents valueForKeyPath:@"magnetLink"] componentsJoinedByString:@"\n"];
    [pasteBoard declareTypes:@[ NSPasteboardTypeString ] owner:nil];
    [pasteBoard setString:links forType:NSPasteboardTypeString];
}

- (void)paste:(id)sender
{
    [self.fController openPasteboard];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    SEL action = menuItem.action;

    if (action == @selector(paste:))
    {
        if ([NSPasteboard.generalPasteboard.types containsObject:NSURLPboardType])
        {
            return YES;
        }

        NSArray* items = [NSPasteboard.generalPasteboard readObjectsForClasses:@[ [NSString class] ] options:nil];
        if (items)
        {
            NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
            for (__strong NSString* pbItem in items)
            {
                pbItem = [pbItem stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (([pbItem rangeOfString:@"magnet:" options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound) ||
                    [detector firstMatchInString:pbItem options:0 range:NSMakeRange(0, pbItem.length)])
                {
                    return YES;
                }
            }
        }

        return NO;
    }

    return YES;
}

- (void)hoverEventBeganForView:(id)view
{
    NSInteger row = [self rowForView:view];
    Torrent* torrent = [self itemAtRow:row];

    BOOL minimal = [self.fDefaults boolForKey:@"SmallView"];
    if (minimal)
    {
        if ([view isKindOfClass:[SmallTorrentCell class]])
        {
            self.fHoverEventDict = @{ @"row" : [NSNumber numberWithInteger:row] };
        }
        else if ([view isKindOfClass:[TorrentCellActionButton class]])
        {
            SmallTorrentCell* smallCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
            smallCell.fIconView.hidden = YES;
        }
    }
    else
    {
        NSString* statusString;
        if ([view isKindOfClass:[TorrentCellRevealButton class]])
        {
            statusString = NSLocalizedString(@"Show the data file in Finder", "Torrent cell -> button info");
        }
        else if ([view isKindOfClass:[TorrentCellControlButton class]])
        {
            if (torrent.active)
                statusString = NSLocalizedString(@"Pause the transfer", "Torrent Table -> tooltip");
            else
            {
                if ([NSAppCurrentEvent() modifierFlags] & NSEventModifierFlagOption)
                {
                    statusString = NSLocalizedString(@"Resume the transfer right away", "Torrent cell -> button info");
                }
                else if (torrent.waitingToStart)
                {
                    statusString = NSLocalizedString(@"Stop waiting to start", "Torrent cell -> button info");
                }
                else
                {
                    statusString = NSLocalizedString(@"Resume the transfer", "Torrent cell -> button info");
                }
            }
        }
        else if ([view isKindOfClass:[TorrentCellActionButton class]])
        {
            statusString = NSLocalizedString(@"Change transfer settings", "Torrent Table -> tooltip");
        }

        if (statusString)
        {
            self.fHoverEventDict = @{ @"string" : statusString, @"row" : [NSNumber numberWithInteger:row] };
        }
    }

    [self reloadVisibleRows];
}

- (void)hoverEventEndedForView:(id)view
{
    NSInteger row = [self rowForView:[view superview]];

    BOOL update = YES;
    BOOL minimal = [self.fDefaults boolForKey:@"SmallView"];
    if (minimal)
    {
        if (minimal && ![view isKindOfClass:[SmallTorrentCell class]])
        {
            if ([view isKindOfClass:[TorrentCellActionButton class]])
            {
                SmallTorrentCell* smallCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
                smallCell.fIconView.hidden = NO;
            }
            update = NO;
        }
    }

    if (update)
    {
        self.fHoverEventDict = nil;
        [self reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}

- (void)toggleGroupRowRatio
{
    BOOL displayGroupRowRatio = [self.fDefaults boolForKey:@"DisplayGroupRowRatio"];
    [self.fDefaults setBool:!displayGroupRowRatio forKey:@"DisplayGroupRowRatio"];
    [self reloadVisibleRows];
}

- (IBAction)toggleControlForTorrent:(id)sender
{
    Torrent* torrent = [self itemAtRow:[self rowForView:[sender superview]]];
    if (torrent.active)
    {
        [self.fController stopTorrents:@[ torrent ]];
    }
    else
    {
        if ([NSEvent modifierFlags] & NSEventModifierFlagOption)
        {
            [self.fController resumeTorrentsNoWait:@[ torrent ]];
        }
        else if (torrent.waitingToStart)
        {
            [self.fController stopTorrents:@[ torrent ]];
        }
        else
        {
            [self.fController resumeTorrents:@[ torrent ]];
        }
    }
}

- (IBAction)revealTorrentFile:(id)sender
{
    Torrent* torrent = [self itemAtRow:[self rowForView:[sender superview]]];
    NSString* location = torrent.dataLocation;
    if (location)
    {
        NSURL* file = [NSURL fileURLWithPath:location];
        [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ file ]];
    }
}

- (IBAction)displayTorrentActionPopover:(id)sender
{
    if (self.fActionPopoverShown)
    {
        return;
    }

    Torrent* torrent = [self itemAtRow:[self rowForView:[sender superview]]];
    NSRect rect = [sender bounds];

    NSPopover* popover = [[NSPopover alloc] init];
    popover.behavior = NSPopoverBehaviorTransient;
    InfoOptionsViewController* infoViewController = [[InfoOptionsViewController alloc] init];
    popover.contentViewController = infoViewController;
    popover.delegate = self;

    [popover showRelativeToRect:rect ofView:sender preferredEdge:NSMaxYEdge];
    [infoViewController setInfoForTorrents:@[ torrent ]];
    [infoViewController updateInfo];

    CGFloat width = NSWidth(rect);

    if (NSMinX(self.window.frame) < width || NSMaxX(self.window.screen.visibleFrame) - NSMinX(self.window.frame) < 72)
    {
        // Ugly hack to hide NSPopover arrow.
        self.fPositioningView = [[NSView alloc] initWithFrame:rect];
        self.fPositioningView.identifier = @"positioningView";
        [self addSubview:self.fPositioningView];
        [popover showRelativeToRect:self.fPositioningView.bounds ofView:self.fPositioningView preferredEdge:NSMaxYEdge];
        self.fPositioningView.bounds = NSOffsetRect(self.fPositioningView.bounds, 0, NSHeight(self.fPositioningView.bounds));
    }
    else
    {
        [popover showRelativeToRect:rect ofView:sender preferredEdge:NSMaxYEdge];
    }
}

//don't show multiple popovers when clicking the gear button repeatedly
- (void)popoverWillShow:(NSNotification*)notification
{
    self.fActionPopoverShown = YES;
}

- (void)popoverDidClose:(NSNotification*)notification
{
    [self.fPositioningView removeFromSuperview];
    self.fPositioningView = nil;
    self.fActionPopoverShown = NO;
}

- (void)togglePiecesBar
{
    NSMutableArray* progressMarks = [NSMutableArray arrayWithCapacity:16];
    for (NSAnimationProgress i = 0.0625; i <= 1.0; i += 0.0625)
    {
        [progressMarks addObject:@(i)];
    }

    //this stops a previous animation
    self.fPiecesBarAnimation = [[NSAnimation alloc] initWithDuration:kToggleProgressSeconds animationCurve:NSAnimationEaseIn];
    self.fPiecesBarAnimation.animationBlockingMode = NSAnimationNonblocking;
    self.fPiecesBarAnimation.progressMarks = progressMarks;
    self.fPiecesBarAnimation.delegate = self;

    [self.fPiecesBarAnimation startAnimation];
}

- (void)animationDidEnd:(NSAnimation*)animation
{
    if (animation == self.fPiecesBarAnimation)
    {
        self.fPiecesBarAnimation = nil;
    }
}

- (void)animation:(NSAnimation*)animation didReachProgressMark:(NSAnimationProgress)progress
{
    if (animation == self.fPiecesBarAnimation)
    {
        if ([self.fDefaults boolForKey:@"PiecesBar"])
        {
            self.piecesBarPercent = progress;
        }
        else
        {
            self.piecesBarPercent = 1.0 - progress;
        }

        self.needsDisplay = YES;
    }
}

- (void)selectAndScrollToRow:(NSInteger)row
{
    NSParameterAssert(row >= 0);
    NSParameterAssert(row < self.numberOfRows);

    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

    NSRect const rowRect = [self rectOfRow:row];
    NSRect const viewRect = self.superview.frame;

    NSPoint scrollOrigin = rowRect.origin;
    scrollOrigin.y += (rowRect.size.height - viewRect.size.height) / 2;
    if (scrollOrigin.y < 0)
    {
        scrollOrigin.y = 0;
    }

    [[self.superview animator] setBoundsOrigin:scrollOrigin];
}

#pragma mark - Private

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (BOOL)pointInLegacyGroupDisclosureRect:(NSPoint)point
{
    NSInteger row = [self rowAtPoint:point];
    if (row < 0 || ![[self itemAtRow:row] isKindOfClass:[TorrentGroup class]])
    {
        return NO;
    }

    NSRect rowRect = [self rectOfRow:row];
    return point.x >= NSMinX(rowRect) && point.x <= NSMinX(rowRect) + kLegacyGroupDisclosureWidth;
}
#endif

- (BOOL)pointInGroupStatusRect:(NSPoint)point
{
    NSInteger row = [self rowAtPoint:point];
    if (row < 0 || ![[self itemAtRow:row] isKindOfClass:[TorrentGroup class]])
    {
        return NO;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSRect rowRect = [self rectOfRow:row];
    return point.x >= NSMaxX(rowRect) - kLegacyGroupStatusWidth;
#else
    //check if click is within the status/ratio rect
    GroupCell* groupCell = [self viewAtColumn:0 row:row makeIfNecessary:NO];
    NSRect titleRect = groupCell.fGroupTitleField.frame;
    CGFloat maxX = NSMaxX(titleRect);

    return point.x > maxX;
#endif
}

@end
