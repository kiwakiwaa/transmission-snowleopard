// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FilePriorityCellView.h"

#include <libtransmission/macos-version.h>

#import "FileListNode.h"
#import "FileOutlineItemDisplay.h"
#import "LegacyConstraints.h"
#import "Torrent.h"

// NSSegmentedControl.trackingMode is 10.10.3+, so 10.10.0-targeted builds use the cell API.
#define TR_FILE_PRIORITY_USES_LEGACY_SEGMENTED_CONTROL_API TR_MACOS_DEPLOYMENT_BEFORE_10_11

@interface FilePriorityCellView ()
@property(nonatomic, weak) NSSegmentedControl* segmentedControl;
@property(nonatomic, weak) NSView* iconsContainerView;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
@property(nonatomic, strong) NSStackView* stackView;
@property(nonatomic, strong) NSImageView* lowPriorityView;
@property(nonatomic, strong) NSImageView* mediumPriorityView;
@property(nonatomic, strong) NSImageView* highPriorityView;
#endif
@property(nonatomic, strong) NSTrackingArea* trackingArea;
@end

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@interface FilePriorityCellView ()
- (void)layoutSubviewsForLegacyFrame;
@end
#endif

@implementation FilePriorityCellView

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize node = _node;
@synthesize hovered = _hovered;
@synthesize segmentedControl = _segmentedControl;
@synthesize iconsContainerView = _iconsContainerView;
#endif
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize stackView = _stackView;
@synthesize lowPriorityView = _lowPriorityView;
@synthesize mediumPriorityView = _mediumPriorityView;
@synthesize highPriorityView = _highPriorityView;
#endif
#endif
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize trackingArea = _trackingArea;
#endif

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        // Create segmented control for hover state
        NSSegmentedControl* segmentedControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        segmentedControl.translatesAutoresizingMaskIntoConstraints = YES;
#else
        segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
#endif
#if TR_FILE_PRIORITY_USES_LEGACY_SEGMENTED_CONTROL_API
        [(NSSegmentedCell*)[segmentedControl cell] setTrackingMode:NSSegmentSwitchTrackingSelectAny];
        [(NSSegmentedCell*)[segmentedControl cell] setControlSize:NSMiniControlSize];
        [segmentedControl setSegmentCount:3];

        for (NSInteger i = 0; i < [segmentedControl segmentCount]; i++)
#else
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

#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        [segmentedControl setTarget:self];
#else
        segmentedControl.target = self;
#endif
        segmentedControl.action = @selector(segmentedControlClicked:);
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        [segmentedControl setHidden:YES];
#else
        segmentedControl.hidden = YES;
#endif

        [self addSubview:segmentedControl];
        _segmentedControl = segmentedControl;

        // Create container view for priority icons
        NSView* iconsContainerView = [[NSView alloc] initWithFrame:NSZeroRect];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        iconsContainerView.translatesAutoresizingMaskIntoConstraints = YES;
#else
        iconsContainerView.translatesAutoresizingMaskIntoConstraints = NO;
#endif
        [self addSubview:iconsContainerView];
        _iconsContainerView = iconsContainerView;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        [self setNeedsDisplay:YES];
#else
        // Setup constraints
        TRActivateConstraints(self,
            @[
                TRMakeLayoutConstraint(segmentedControl, NSLayoutAttributeCenterX, NSLayoutRelationEqual, self, NSLayoutAttributeCenterX, 0.0),
                TRMakeLayoutConstraint(segmentedControl, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),

                TRMakeLayoutConstraint(iconsContainerView, NSLayoutAttributeCenterX, NSLayoutRelationEqual, self, NSLayoutAttributeCenterX, 0.0),
                TRMakeLayoutConstraint(iconsContainerView, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),
                TRMakeLayoutConstraint(iconsContainerView, NSLayoutAttributeWidth, NSLayoutRelationLessThanOrEqual, self, NSLayoutAttributeWidth, 0.0),
                TRMakeLayoutConstraint(iconsContainerView, NSLayoutAttributeHeight, NSLayoutRelationLessThanOrEqual, self, NSLayoutAttributeHeight, 0.0),
            ]);
#endif

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
        [self updateIconsContainerView];
#endif

        _hovered = NO;
    }
    return self;
}

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (void)updateIconsContainerView
{
    NSImage* lowPriority = [NSImage imageNamed:@"PriorityLowTemplate"];
    NSImage* mediumPriority = [NSImage imageNamed:@"PriorityNormalTemplate"];
    NSImage* highPriority = [NSImage imageNamed:@"PriorityHighTemplate"];

    NSImageView* lowPriorityView = [[NSImageView alloc] init];
    lowPriorityView.image = lowPriority;
    NSImageView* mediumPriorityView = [[NSImageView alloc] init];
    mediumPriorityView.image = mediumPriority;
    NSImageView* highPriorityView = [[NSImageView alloc] init];
    highPriorityView.image = highPriority;

    NSStackView* stackView = [[NSStackView alloc] init];
    stackView.spacing = -TRFileOutlinePriorityImageOverlap();

#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
    [stackView setViews:@[ lowPriorityView, mediumPriorityView, highPriorityView ] inGravity:NSStackViewGravityCenter];
#else
    [stackView addArrangedSubview:lowPriorityView];
    [stackView addArrangedSubview:mediumPriorityView];
    [stackView addArrangedSubview:highPriorityView];
#endif

    self.stackView = stackView;
    self.lowPriorityView = lowPriorityView;
    self.mediumPriorityView = mediumPriorityView;
    self.highPriorityView = highPriorityView;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
    for (NSImageView* priorityView in @[ lowPriorityView, mediumPriorityView, highPriorityView ])
    {
        priorityView.translatesAutoresizingMaskIntoConstraints = NO;
        TRActivateConstraints(priorityView,
            @[
                TRMakeLayoutConstraint(
                    priorityView,
                    NSLayoutAttributeWidth,
                    NSLayoutRelationEqual,
                    nil,
                    NSLayoutAttributeNotAnAttribute,
                    priorityView.image.size.width),
                TRMakeLayoutConstraint(
                    priorityView,
                    NSLayoutAttributeHeight,
                    NSLayoutRelationEqual,
                    nil,
                    NSLayoutAttributeNotAnAttribute,
                    priorityView.image.size.height),
            ]);
    }
#endif

    [self.iconsContainerView addSubview:stackView];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;

    CGFloat height = lowPriority.size.height;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
    TRActivateConstraints(self.iconsContainerView,
        @[
            TRMakeLayoutConstraint(stackView, NSLayoutAttributeLeading, NSLayoutRelationEqual, self.iconsContainerView, NSLayoutAttributeLeading, 0.0),
            TRMakeLayoutConstraint(stackView, NSLayoutAttributeTrailing, NSLayoutRelationEqual, self.iconsContainerView, NSLayoutAttributeTrailing, 0.0),
            TRMakeLayoutConstraint(stackView, NSLayoutAttributeTop, NSLayoutRelationEqual, self.iconsContainerView, NSLayoutAttributeTop, 0.0),
            TRMakeLayoutConstraint(stackView, NSLayoutAttributeBottom, NSLayoutRelationEqual, self.iconsContainerView, NSLayoutAttributeBottom, 0.0),
            TRMakeLayoutConstraint(stackView, NSLayoutAttributeHeight, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, height),
        ]);
#else
    __auto_type superview = stackView.superview;
    [NSLayoutConstraint activateConstraints:@[
        [stackView.leadingAnchor constraintEqualToAnchor:superview.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:superview.trailingAnchor],
        [stackView.topAnchor constraintEqualToAnchor:superview.topAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:superview.bottomAnchor],
        [stackView.heightAnchor constraintEqualToConstant:height]
    ]];
#endif
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
- (void)setPriorityIconViews:(NSArray*)views
{
    [self.stackView setViews:views inGravity:NSStackViewGravityCenter];
}
#else
- (void)setPriorityIconView:(NSImageView*)view visible:(BOOL)visible
{
    view.hidden = !visible;
}
#endif
#endif

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
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        [self.segmentedControl setHidden:NO];
        [self.iconsContainerView setHidden:YES];
#else
        self.segmentedControl.hidden = NO;
        self.iconsContainerView.hidden = YES;
#endif

        [self.segmentedControl setSelected:[priorities containsObject:@(TR_PRI_LOW)] forSegment:0];
        [self.segmentedControl setSelected:[priorities containsObject:@(TR_PRI_NORMAL)] forSegment:1];
        [self.segmentedControl setSelected:[priorities containsObject:@(TR_PRI_HIGH)] forSegment:2];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        [self layoutSubviewsForLegacyFrame];
#endif
    }
    else
    {
        // Show static priority icons
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        [self.segmentedControl setHidden:YES];
        [self.iconsContainerView setHidden:NO];
#else
        self.segmentedControl.hidden = YES;
        self.iconsContainerView.hidden = NO;
#endif

        [self updatePriorityIcons:priorities];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        [self layoutSubviewsForLegacyFrame];
#endif
    }

    // Update tooltip
    [self updateTooltip:priorities];
}

- (void)updatePriorityIcons:(NSSet*)priorities
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSArray* images = TRFileOutlinePriorityImages(priorities, self.backgroundStyle);
    CGFloat const imageOverlap = TRFileOutlinePriorityImageOverlap();

    for (NSView* subview in self.iconsContainerView.subviews)
    {
        [subview removeFromSuperview];
    }

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
        totalWidth -= imageOverlap * (images.count - 1);
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
        x += image.size.width - imageOverlap;
    }
#else
#if TR_MACOS_DEPLOYMENT_BEFORE_10_14
    NSArray* images = TRFileOutlinePriorityImages(priorities, self.backgroundStyle);
    NSUInteger imageIndex = 0;
#endif
    NSUInteger const count = priorities.count;
    if (count == 0)
    {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_14
        self.mediumPriorityView.image = images.count > 0 ? images[imageIndex] : nil;
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
        [self setPriorityIconViews:@[ self.mediumPriorityView ]];
#else
        [self setPriorityIconView:self.lowPriorityView visible:NO];
        [self setPriorityIconView:self.mediumPriorityView visible:YES];
        [self setPriorityIconView:self.highPriorityView visible:NO];
#endif
    }
    else
    {
        BOOL const hasLowPriority = [priorities containsObject:@(TR_PRI_LOW)];
        BOOL const hasMediumPriority = [priorities containsObject:@(TR_PRI_NORMAL)];
        BOOL const hasHighPriority = [priorities containsObject:@(TR_PRI_HIGH)];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
        NSMutableArray* visiblePriorityViews = [NSMutableArray arrayWithCapacity:count];
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_14
        if (hasLowPriority)
        {
            self.lowPriorityView.image = images[imageIndex++];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
            [visiblePriorityViews addObject:self.lowPriorityView];
#endif
        }
        if (hasMediumPriority)
        {
            self.mediumPriorityView.image = images[imageIndex++];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
            [visiblePriorityViews addObject:self.mediumPriorityView];
#endif
        }
        if (hasHighPriority)
        {
            self.highPriorityView.image = images[imageIndex++];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
            [visiblePriorityViews addObject:self.highPriorityView];
#endif
        }
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_11
        [self setPriorityIconViews:visiblePriorityViews];
#else
        [self setPriorityIconView:self.lowPriorityView visible:hasLowPriority];
        [self setPriorityIconView:self.mediumPriorityView visible:hasMediumPriority];
        [self setPriorityIconView:self.highPriorityView visible:hasHighPriority];
#endif
    }
#endif
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self layoutSubviewsForLegacyFrame];
}

- (void)layoutSubviewsForLegacyFrame
{
    self.segmentedControl.frame = NSMakeRect(NSMidX(self.bounds) - 14.0, NSMidY(self.bounds) - 9.0, 28.0, 18.0);
    if (![self.iconsContainerView isHidden] && self.node)
    {
        self.iconsContainerView.frame = NSMakeRect(
            NSMidX(self.bounds) - NSWidth(self.iconsContainerView.frame) / 2.0,
            NSMidY(self.bounds) - NSHeight(self.iconsContainerView.frame) / 2.0,
            NSWidth(self.iconsContainerView.frame),
            NSHeight(self.iconsContainerView.frame));
    }
}
#endif

- (void)segmentedControlClicked:(NSSegmentedControl*)sender
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
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
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UpdateUI" object:nil];
#else
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateUI" object:nil];
#endif
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];

#if TR_MACOS_DEPLOYMENT_BEFORE_10_14
    [self updateDisplay];
#else
    NSColor* priorityColor = backgroundStyle == NSBackgroundStyleEmphasized ? NSColor.whiteColor : NSColor.darkGrayColor;
    self.lowPriorityView.contentTintColor = priorityColor;
    self.mediumPriorityView.contentTintColor = priorityColor;
    self.highPriorityView.contentTintColor = priorityColor;
#endif
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    if (self.trackingArea)
    {
        [self removeTrackingArea:self.trackingArea];
    }

    NSTrackingAreaOptions options = static_cast<NSTrackingAreaOptions>(NSTrackingMouseEnteredAndExited) |
        static_cast<NSTrackingAreaOptions>(NSTrackingActiveInActiveApp);

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

    self.toolTip = TRFileOutlinePriorityTooltip(priorities);
}

@end
