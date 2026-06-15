// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FilePriorityCellView.h"
#import "FileListNode.h"
#import "NSImageAdditions.h"
#import "Torrent.h"

static CGFloat const kImageOverlap = 1.0;

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
static NSImage* PriorityTemplateImage(NSString* imageName, NSColor* color)
{
    NSImage* image = [NSImage imageNamed:imageName];
    if (image.size.width > 0.0 && image.size.height > 0.0)
    {
        return [image imageWithColor:color];
    }

    NSImage* fallback = [[NSImage alloc] initWithSize:NSMakeSize(9.0, 12.0)];
    [fallback lockFocus];
    [color setFill];

    NSBezierPath* path = [NSBezierPath bezierPath];
    if ([imageName isEqualToString:@"PriorityHighTemplate"])
    {
        [path moveToPoint:NSMakePoint(4.5, 11.0)];
        [path lineToPoint:NSMakePoint(8.0, 6.5)];
        [path lineToPoint:NSMakePoint(5.8, 6.5)];
        [path lineToPoint:NSMakePoint(5.8, 1.0)];
        [path lineToPoint:NSMakePoint(3.2, 1.0)];
        [path lineToPoint:NSMakePoint(3.2, 6.5)];
        [path lineToPoint:NSMakePoint(1.0, 6.5)];
    }
    else if ([imageName isEqualToString:@"PriorityLowTemplate"])
    {
        [path moveToPoint:NSMakePoint(4.5, 1.0)];
        [path lineToPoint:NSMakePoint(8.0, 5.5)];
        [path lineToPoint:NSMakePoint(5.8, 5.5)];
        [path lineToPoint:NSMakePoint(5.8, 11.0)];
        [path lineToPoint:NSMakePoint(3.2, 11.0)];
        [path lineToPoint:NSMakePoint(3.2, 5.5)];
        [path lineToPoint:NSMakePoint(1.0, 5.5)];
    }
    else
    {
        [path appendBezierPathWithRect:NSMakeRect(2.0, 5.0, 5.0, 2.0)];
    }

    [path closePath];
    [path fill];
    [fallback unlockFocus];

    return fallback;
}
#endif

@interface FilePriorityCellView ()
@property(nonatomic, TR_OBJC_WEAK) NSSegmentedControl* segmentedControl;
@property(nonatomic, TR_OBJC_WEAK) NSView* iconsContainerView;
@property(nonatomic, strong) NSTrackingArea* trackingArea;
@end

@implementation FilePriorityCellView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        // Create segmented control for hover state
        NSSegmentedControl* segmentedControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        segmentedControl.translatesAutoresizingMaskIntoConstraints = YES;
        [(NSSegmentedCell*)[segmentedControl cell] setTrackingMode:NSSegmentSwitchTrackingSelectAny];
        [(NSSegmentedCell*)[segmentedControl cell] setControlSize:NSMiniControlSize];
        [segmentedControl setSegmentCount:3];

        for (NSInteger i = 0; i < [segmentedControl segmentCount]; i++)
#else
        segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
        segmentedControl.trackingMode = NSSegmentSwitchTrackingSelectAny;
        segmentedControl.controlSize = NSControlSizeMini;
        segmentedControl.segmentCount = 3;

        for (NSInteger i = 0; i < segmentedControl.segmentCount; i++)
#endif
        {
            [segmentedControl setLabel:@"" forSegment:i];
            [segmentedControl setWidth:9.0f forSegment:i];
        }

        [segmentedControl setImage:[NSImage imageNamed:@"PriorityControlLow"] forSegment:0];
        [segmentedControl setImage:[NSImage imageNamed:@"PriorityControlNormal"] forSegment:1];
        [segmentedControl setImage:[NSImage imageNamed:@"PriorityControlHigh"] forSegment:2];

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        [segmentedControl setTarget:self];
#else
        segmentedControl.target = self;
#endif
        segmentedControl.action = @selector(segmentedControlClicked:);
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        [segmentedControl setHidden:YES];
#else
        segmentedControl.hidden = YES;
#endif

        [self addSubview:segmentedControl];
        _segmentedControl = segmentedControl;

        // Create container view for priority icons
        NSView* iconsContainerView = [[NSView alloc] initWithFrame:NSZeroRect];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        iconsContainerView.translatesAutoresizingMaskIntoConstraints = YES;
#else
        iconsContainerView.translatesAutoresizingMaskIntoConstraints = NO;
#endif
        [self addSubview:iconsContainerView];
        _iconsContainerView = iconsContainerView;

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        [self setNeedsDisplay:YES];
#else
        // Setup constraints
        [NSLayoutConstraint activateConstraints:@[
            [segmentedControl.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [segmentedControl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [iconsContainerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [iconsContainerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [iconsContainerView.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor],
            [iconsContainerView.heightAnchor constraintLessThanOrEqualToAnchor:self.heightAnchor],
        ]];
#endif

        _hovered = NO;
    }
    return self;
}

- (void)setNode:(FileListNode*)node
{
    _node = node;

    [self updateDisplay];
}

- (void)setHovered:(BOOL)hovered
{
    _hovered = hovered;

    [self updateDisplay];
}

- (void)updateDisplay
{
    if (!self.node)
    {
        return;
    }

    FileListNode* node = self.node;
    Torrent* torrent = node.torrent;
    NSSet* priorities = [torrent filePrioritiesForIndexes:node.indexes];

    NSUInteger const count = priorities.count;
    if (self.hovered && count > 0)
    {
        // Show segmented control
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        [self.segmentedControl setHidden:NO];
        [self.iconsContainerView setHidden:YES];
#else
        self.segmentedControl.hidden = NO;
        self.iconsContainerView.hidden = YES;
#endif

        [self.segmentedControl setSelected:[priorities containsObject:@(TR_PRI_LOW)] forSegment:0];
        [self.segmentedControl setSelected:[priorities containsObject:@(TR_PRI_NORMAL)] forSegment:1];
        [self.segmentedControl setSelected:[priorities containsObject:@(TR_PRI_HIGH)] forSegment:2];
    }
    else
    {
        // Show static priority icons
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        [self.segmentedControl setHidden:YES];
        [self.iconsContainerView setHidden:NO];
#else
        self.segmentedControl.hidden = YES;
        self.iconsContainerView.hidden = NO;
#endif

        [self updatePriorityIcons:priorities];
    }

    // Update tooltip
    [self updateTooltip:priorities];
}

- (void)updatePriorityIcons:(NSSet*)priorities
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    // Remove all existing image views
#endif
    for (NSView* subview in self.iconsContainerView.subviews)
    {
        [subview removeFromSuperview];
    }

    NSUInteger const count = priorities.count;
    NSMutableArray* images = [NSMutableArray arrayWithCapacity:MAX(count, 1u)];

    if (count == 0)
    {
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        NSImage* image = PriorityTemplateImage(@"PriorityNormalTemplate", [NSColor lightGrayColor]);
#else
        NSImage* image = [[NSImage imageNamed:@"PriorityNormalTemplate"] imageWithColor:NSColor.lightGrayColor];
#endif
        [images addObject:image];
    }
    else
    {
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        NSColor* priorityColor = self.backgroundStyle == NSBackgroundStyleEmphasized ? [NSColor whiteColor] : [NSColor darkGrayColor];
#else
        NSColor* priorityColor = self.backgroundStyle == NSBackgroundStyleEmphasized ? NSColor.whiteColor : NSColor.darkGrayColor;
#endif

        if ([priorities containsObject:@(TR_PRI_LOW)])
        {
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
            [images addObject:PriorityTemplateImage(@"PriorityLowTemplate", priorityColor)];
#else
            NSImage* image = [[NSImage imageNamed:@"PriorityLowTemplate"] imageWithColor:priorityColor];
            [images addObject:image];
#endif
        }
        if ([priorities containsObject:@(TR_PRI_NORMAL)])
        {
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
            [images addObject:PriorityTemplateImage(@"PriorityNormalTemplate", priorityColor)];
#else
            NSImage* image = [[NSImage imageNamed:@"PriorityNormalTemplate"] imageWithColor:priorityColor];
            [images addObject:image];
#endif
        }
        if ([priorities containsObject:@(TR_PRI_HIGH)])
        {
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
            [images addObject:PriorityTemplateImage(@"PriorityHighTemplate", priorityColor)];
#else
            NSImage* image = [[NSImage imageNamed:@"PriorityHighTemplate"] imageWithColor:priorityColor];
            [images addObject:image];
#endif
        }
    }

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    CGFloat totalWidth = 0.0;
    CGFloat maxHeight = 0.0;
    for (NSImage* image in images)
    {
        if (image.size.width <= 0.0 || image.size.height <= 0.0)
        {
            continue;
        }
        totalWidth += image.size.width;
        maxHeight = MAX(maxHeight, image.size.height);
    }
    if (images.count > 1)
    {
        totalWidth -= kImageOverlap * (images.count - 1);
    }

    self.iconsContainerView.frame = NSMakeRect(NSMidX(self.bounds) - totalWidth / 2.0, NSMidY(self.bounds) - maxHeight / 2.0, totalWidth, maxHeight);

    CGFloat x = 0.0;
    for (NSImage* image in images)
    {
        if (image.size.width <= 0.0 || image.size.height <= 0.0)
        {
            continue;
        }
        NSImageView* imageView = [[NSImageView alloc]
            initWithFrame:NSMakeRect(x, (maxHeight - image.size.height) / 2.0, image.size.width, image.size.height)];
        imageView.image = image;
        [self.iconsContainerView addSubview:imageView];
        x += image.size.width - kImageOverlap;
    }
#else
    NSView* previousView = nil;

    for (NSImage* image in images)
    {
        NSImageView* imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.image = image;
        [self.iconsContainerView addSubview:imageView];

        NSSize const imageSize = image.size;

        [NSLayoutConstraint activateConstraints:@[
            [imageView.widthAnchor constraintEqualToConstant:imageSize.width],
            [imageView.heightAnchor constraintEqualToConstant:imageSize.height],
            [imageView.centerYAnchor constraintEqualToAnchor:self.iconsContainerView.centerYAnchor],
        ]];

        if (previousView == nil)
        {
            [imageView.leadingAnchor constraintEqualToAnchor:self.iconsContainerView.leadingAnchor].active = YES;
        }
        else
        {
            [imageView.leadingAnchor constraintEqualToAnchor:previousView.trailingAnchor constant:-kImageOverlap].active = YES;
        }

        previousView = imageView;
    }

    if (previousView)
    {
        [previousView.trailingAnchor constraintEqualToAnchor:self.iconsContainerView.trailingAnchor].active = YES;
    }
#endif
}

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
- (void)layout
{
    [super layout];

    self.segmentedControl.frame = NSMakeRect(NSMidX(self.bounds) - 14.0, NSMidY(self.bounds) - 9.0, 28.0, 18.0);
    if (![self.iconsContainerView isHidden] && self.node)
    {
        Torrent* torrent = self.node.torrent;
        [self updatePriorityIcons:[torrent filePrioritiesForIndexes:self.node.indexes]];
    }
}
#endif

- (void)segmentedControlClicked:(NSSegmentedControl*)sender
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    NSInteger segment = [sender selectedSegment];
#else
    NSInteger segment = sender.selectedSegment;
#endif
    if (segment == -1)
    {
        return;
    }

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

    FileListNode* node = self.node;
    Torrent* torrent = node.torrent;
    [torrent setFilePriority:priority forIndexes:node.indexes];

    // Notify that we need to refresh
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UpdateUI" object:nil];
#else
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateUI" object:nil];
#endif
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self updateDisplay];
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    if (self.trackingArea)
    {
        [self removeTrackingArea:self.trackingArea];
    }

    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp;

    // Check if mouse is currently inside the bounds
    NSPoint mouseLocation = [self.window mouseLocationOutsideOfEventStream];
    NSPoint localPoint = [self convertPoint:mouseLocation fromView:nil];
    if (NSPointInRect(localPoint, self.bounds))
    {
        options |= NSTrackingAssumeInside;
        if (!self.hovered)
        {
            self.hovered = YES;
        }
    }
    else
    {
        // Mouse is not inside, reset hovered state
        if (self.hovered)
        {
            self.hovered = NO;
        }
    }

    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)mouseEntered:(NSEvent*)event
{
    self.hovered = YES;
}

- (void)mouseExited:(NSEvent*)event
{
    self.hovered = NO;
}

- (void)updateTooltip:(NSSet*)priorities
{
    if (!self.node)
    {
        return;
    }

    NSString* tooltip = nil;
    switch (priorities.count)
    {
    case 0:
        tooltip = NSLocalizedString(@"Priority Not Available", "files tab -> tooltip");
        break;
    case 1:
        switch ([[priorities anyObject] intValue])
        {
        case TR_PRI_LOW:
            tooltip = NSLocalizedString(@"Low Priority", "files tab -> tooltip");
            break;
        case TR_PRI_HIGH:
            tooltip = NSLocalizedString(@"High Priority", "files tab -> tooltip");
            break;
        case TR_PRI_NORMAL:
            tooltip = NSLocalizedString(@"Normal Priority", "files tab -> tooltip");
            break;
        }
        break;
    default:
        tooltip = NSLocalizedString(@"Multiple Priorities", "files tab -> tooltip");
        break;
    }
    self.toolTip = tooltip;
}

@end
