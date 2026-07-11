// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "TorrentCell.h"
#import "CocoaCompatibility.h"
#import "LegacyStackView.h"
#import "ProgressBarView.h"
#import "ProgressGradients.h"
#import "Torrent.h"
#import "NSImageAdditions.h"

@implementation TorrentCell

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fActionButton = _fActionButton;
@synthesize fControlButton = _fControlButton;
@synthesize fRevealButton = _fRevealButton;
@synthesize fIconView = _fIconView;
@synthesize fGroupIndicatorView = _fGroupIndicatorView;
@synthesize fStackView = _fStackView;
@synthesize fTorrentTitleField = _fTorrentTitleField;
@synthesize fTorrentPriorityView = _fTorrentPriorityView;
@synthesize fTorrentPriorityViewWidthConstraint = _fTorrentPriorityViewWidthConstraint;
@synthesize fTorrentProgressField = _fTorrentProgressField;
@synthesize fTorrentStatusField = _fTorrentStatusField;
@synthesize fTorrentProgressBarView = _fTorrentProgressBarView;
@synthesize fTorrentTableView = _fTorrentTableView;
#endif

- (void)awakeFromNib
{
    [super awakeFromNib];
    TRCheckExpectedStackViewClass(self.fStackView, NSStringFromClass(self.class), @"fStackView");
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (void)layout
{
    [super layout];
    [self layoutTorrentCellForLegacyAppKit];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
    [super resizeSubviewsWithOldSize:oldSize];
    [self layoutTorrentCellForLegacyAppKit];
}

- (void)layoutTorrentCellForLegacyAppKit
{
    CGFloat const width = NSWidth(self.bounds);
    CGFloat const height = NSHeight(self.bounds);
    BOOL const small = [self isKindOfClass:NSClassFromString(@"SmallTorrentCell")];

    if (small)
    {
        CGFloat const centerY = floor((height - 14.0) / 2.0);
        self.fGroupIndicatorView.frame = NSMakeRect(0.0, floor((height - 6.0) / 2.0), 6.0, 6.0);
        self.fIconView.frame = NSMakeRect(14.0, floor((height - 16.0) / 2.0), 16.0, 16.0);
        self.fActionButton.frame = self.fIconView.frame;
        self.fRevealButton.frame = NSMakeRect(width - 22.0, centerY, 14.0, 14.0);
        self.fControlButton.frame = NSMakeRect(NSMinX(self.fRevealButton.frame) - 17.0, centerY, 14.0, 14.0);

        CGFloat const left = 45.0;
        CGFloat const right = [self.fControlButton isHidden] ? width - 8.0 : NSMinX(self.fControlButton.frame) - 12.0;
        CGFloat const statusWidth = 130.0;
        CGFloat const stackWidth = MAX(40.0, MIN(240.0, right - left - statusWidth));
        self.fStackView.frame = NSMakeRect(left, floor((height - 15.0) / 2.0), stackWidth, 15.0);
        [self.fStackView layoutLegacySubviews];
        self.fTorrentStatusField.frame = NSMakeRect(
            NSMaxX(self.fStackView.frame) + 4.0,
            floor((height - 14.0) / 2.0),
            MAX(40.0, right - NSMaxX(self.fStackView.frame) - 4.0),
            14.0);
        self.fTorrentProgressBarView.frame = NSMakeRect(left, floor((height - 18.0) / 2.0), MAX(10.0, right - left), 18.0);
        return;
    }

    self.fGroupIndicatorView.frame = NSMakeRect(0.0, floor((height - 10.0) / 2.0), 10.0, 10.0);
    self.fIconView.frame = NSMakeRect(13.0, floor((height - 36.0) / 2.0), 36.0, 36.0);
    self.fActionButton.frame = NSMakeRect(NSMinX(self.fIconView.frame) + 10.0, NSMinY(self.fIconView.frame) + 10.0, 16.0, 16.0);
    self.fRevealButton.frame = NSMakeRect(width - 22.0, floor((height - 14.0) / 2.0), 14.0, 14.0);
    self.fControlButton.frame = NSMakeRect(NSMinX(self.fRevealButton.frame) - 17.0, NSMinY(self.fRevealButton.frame), 14.0, 14.0);

    CGFloat const left = 65.0;
    CGFloat const right = NSMinX(self.fControlButton.frame) - 14.0;
    CGFloat const contentWidth = MAX(80.0, right - left);
    self.fStackView.frame = NSMakeRect(left, 3.0, contentWidth, 16.0);
    [self.fStackView layoutLegacySubviews];
    self.fTorrentProgressField.frame = NSMakeRect(left - 2.0, 21.0, contentWidth + 4.0, 13.0);
    self.fTorrentProgressBarView.frame = NSMakeRect(left, 36.0, contentWidth, 14.0);
    self.fTorrentStatusField.frame = NSMakeRect(left - 2.0, 50.0, contentWidth + 4.0, 13.0);
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    if (self.window != nil)
    {
        [self setNeedsDisplay:YES];
        for (NSView* subview in self.subviews)
        {
            [subview setNeedsDisplay:YES];
        }
    }
}
#endif

- (void)drawRect:(NSRect)dirtyRect
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
    [self layoutTorrentCellForLegacyAppKit];
#endif

    if (self.fTorrentTableView)
    {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        NSInteger const row = [self.fTorrentTableView rowForView:self];
        BOOL const selected = row >= 0 && [self.fTorrentTableView isRowSelected:row];
        if (!selected)
        {
            NSColor* color = (row % 2) == 0 ? [NSColor colorWithCalibratedWhite:0.985 alpha:1.0] :
                                              [NSColor colorWithCalibratedWhite:0.955 alpha:1.0];
            [color setFill];
            NSRectFill(self.bounds);
            [[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] setStroke];
            NSBezierPath* line = [NSBezierPath bezierPath];
            [line moveToPoint:NSMakePoint(0.0, NSMaxY(self.bounds) - 0.5)];
            [line lineToPoint:NSMakePoint(NSWidth(self.bounds), NSMaxY(self.bounds) - 0.5)];
            [line stroke];
        }
#endif

        Torrent* torrent = (Torrent*)self.objectValue;

        NSRect barRect = self.fTorrentProgressBarView.frame;
        [ProgressBarView.sharedInstance drawBarInRect:barRect forTableView:self.fTorrentTableView withTorrent:torrent];

        if (torrent.priority != TR_PRI_NORMAL)
        {
            NSColor* priorityColor = self.backgroundStyle == NSBackgroundStyleEmphasized ? NSColor.whiteColor : TRLabelColor();
            NSImage* priorityImage = [[NSImage imageNamed:(torrent.priority == TR_PRI_HIGH ? @"PriorityHighTemplate" : @"PriorityLowTemplate")]
                imageWithColor:priorityColor];

            self.fTorrentPriorityView.image = priorityImage;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
            [self.fStackView setVisibilityPriority:TRLegacyStackViewVisibilityPriorityMustHold forView:self.fTorrentPriorityView];
#else
            [self.fStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:self.fTorrentPriorityView];
#endif
        }
        else
        {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
            [self.fStackView setVisibilityPriority:TRLegacyStackViewVisibilityPriorityNotVisible forView:self.fTorrentPriorityView];
#else
            [self.fStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.fTorrentPriorityView];
#endif
        }
    }

    [super drawRect:dirtyRect];
}

// otherwise progress bar is inverted
- (BOOL)isFlipped
{
    return YES;
}

@end
