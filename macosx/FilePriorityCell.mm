// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FilePriorityCell.h"

#import "FileListNode.h"
#import "FileOutlineItemDisplay.h"
#import "FileOutlineView.h"
#import "Torrent.h"

@implementation FilePriorityCell

- (instancetype)init
{
    if ((self = [super init]))
    {
        [self setTrackingMode:NSSegmentSwitchTrackingSelectAny];
#if TR_MACOS_SDK_BEFORE_10_12
        [self setControlSize:NSMiniControlSize];
#else
        [self setControlSize:NSControlSizeMini];
#endif
        [self setSegmentCount:3];

        for (NSInteger i = 0; i < [self segmentCount]; i++)
        {
            [self setLabel:@"" forSegment:i];
            [self setWidth:9.0 forSegment:i];
        }

        [self setImage:[NSImage imageNamed:@"PriorityControlLow"] forSegment:0];
        [self setImage:[NSImage imageNamed:@"PriorityControlNormal"] forSegment:1];
        [self setImage:[NSImage imageNamed:@"PriorityControlHigh"] forSegment:2];

        _hovered = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    FilePriorityCell* copy = [super copyWithZone:zone];
    [copy setRepresentedObject:self.representedObject];
    copy.hovered = self.hovered;
    return copy;
}

- (void)setSelected:(BOOL)flag forSegment:(NSInteger)segment
{
    [super setSelected:flag forSegment:segment];

    tr_priority_t priority;
    switch (segment)
    {
    case 0:
        priority = TR_PRI_LOW;
        break;
    case 1:
        priority = TR_PRI_NORMAL;
        break;
    case 2:
        priority = TR_PRI_HIGH;
        break;
    default:
        NSAssert1(NO, @"Unknown segment: %ld", segment);
        return;
    }

    FileListNode* node = self.representedObject;
    [node.torrent setFilePriority:priority forIndexes:node.indexes];

    FileOutlineView* controlView = (FileOutlineView*)self.controlView;
    controlView.needsDisplay = YES;
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateUI" object:nil];
}

- (void)addTrackingAreasForView:(NSView*)controlView
                         inRect:(NSRect)cellFrame
                   withUserInfo:(NSDictionary*)userInfo
                  mouseLocation:(NSPoint)mouseLocation
{
    NSTrackingAreaOptions options = static_cast<NSTrackingAreaOptions>(NSTrackingEnabledDuringMouseDrag) |
        static_cast<NSTrackingAreaOptions>(NSTrackingMouseEnteredAndExited) | static_cast<NSTrackingAreaOptions>(NSTrackingActiveAlways);

    if (NSMouseInRect(mouseLocation, cellFrame, [controlView isFlipped]))
    {
        options |= NSTrackingAssumeInside;
        [controlView setNeedsDisplayInRect:cellFrame];
    }

    NSTrackingArea* area = [[NSTrackingArea alloc] initWithRect:cellFrame options:options owner:controlView userInfo:userInfo];
    [controlView addTrackingArea:area];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
    FileListNode* node = self.representedObject;
    NSSet* priorities = [node.torrent filePrioritiesForIndexes:node.indexes];

    if (self.hovered && priorities.count > 0)
    {
        [super setSelected:[priorities containsObject:@(TR_PRI_LOW)] forSegment:0];
        [super setSelected:[priorities containsObject:@(TR_PRI_NORMAL)] forSegment:1];
        [super setSelected:[priorities containsObject:@(TR_PRI_HIGH)] forSegment:2];

        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    NSArray* images = TRFileOutlinePriorityImages(priorities, self.backgroundStyle);
    CGFloat totalWidth = 0.0;
    CGFloat maxHeight = 0.0;
    CGFloat const overlap = TRFileOutlinePriorityImageOverlap();

    for (NSImage* image in images)
    {
        totalWidth += image.size.width;
        maxHeight = MAX(maxHeight, image.size.height);
    }
    if (images.count > 1)
    {
        totalWidth -= overlap * (images.count - 1);
    }

    CGFloat currentWidth = floor(NSMidX(cellFrame) - totalWidth * 0.5);
    for (NSImage* image in images)
    {
        NSSize const imageSize = image.size;
        NSRect const imageRect = NSMakeRect(
            currentWidth,
            floor(NSMidY(cellFrame) - imageSize.height * 0.5),
            imageSize.width,
            imageSize.height);

        [image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0
            respectFlipped:YES
                     hints:nil];

        currentWidth += imageSize.width - overlap;
    }
}

@end
