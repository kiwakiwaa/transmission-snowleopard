// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyDockTile.h"

#import "BadgeView.h"
#import "CocoaCompatibility.h"

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

static CGFloat const kLegacyDockIconFallbackSize = 128.0;
static CGFloat const kLegacyDockSpeedBadgeScale = 0.72;
static CGFloat const kLegacyDockSpeedBadgeSpacing = 2.0;

static void TRDrawLegacyDockBadgeBackground(NSImage* badge, NSRect rect)
{
    NSSize const sourceSize = badge.size;
    CGFloat const sourceCapWidth = sourceSize.height * 0.5;
    CGFloat const destinationCapWidth = NSHeight(rect) * 0.5;

    NSRect const sourceLeft = NSMakeRect(0.0, 0.0, sourceCapWidth, sourceSize.height);
    NSRect const sourceMiddle = NSMakeRect(
        sourceCapWidth, 0.0, sourceSize.width - sourceCapWidth * 2.0, sourceSize.height);
    NSRect const sourceRight = NSMakeRect(sourceSize.width - sourceCapWidth, 0.0, sourceCapWidth, sourceSize.height);

    NSRect const destinationLeft = NSMakeRect(NSMinX(rect), NSMinY(rect), destinationCapWidth, NSHeight(rect));
    NSRect const destinationMiddle = NSMakeRect(
        NSMinX(rect) + destinationCapWidth,
        NSMinY(rect),
        NSWidth(rect) - destinationCapWidth * 2.0,
        NSHeight(rect));
    NSRect const destinationRight = NSMakeRect(
        NSMaxX(rect) - destinationCapWidth, NSMinY(rect), destinationCapWidth, NSHeight(rect));

    [badge drawInRect:destinationLeft fromRect:sourceLeft operation:NSCompositingOperationSourceOver fraction:1.0];
    [badge drawInRect:destinationMiddle fromRect:sourceMiddle operation:NSCompositingOperationSourceOver fraction:1.0];
    [badge drawInRect:destinationRight fromRect:sourceRight operation:NSCompositingOperationSourceOver fraction:1.0];
}

@interface LegacyDockTile ()

@property(nonatomic, readonly) BadgeView* fBadgeView;
@property(nonatomic, readonly) NSImage* fOriginalIcon;
@property(nonatomic, readonly) NSString* fBadgeLabel;
@property(nonatomic) BOOL fShowsSpeedBadge;
@property(nonatomic) BOOL fShowsDownloadSpeedBadge;
@property(nonatomic) BOOL fShowsUploadSpeedBadge;

- (void)drawSpeedBadgeLayerInRect:(NSRect)iconRect;

@end

@implementation LegacyDockTile

@synthesize fBadgeView = _fBadgeView;
@synthesize fOriginalIcon = _fOriginalIcon;
@synthesize fBadgeLabel = _fBadgeLabel;
@synthesize fShowsSpeedBadge = _fShowsSpeedBadge;
@synthesize fShowsDownloadSpeedBadge = _fShowsDownloadSpeedBadge;
@synthesize fShowsUploadSpeedBadge = _fShowsUploadSpeedBadge;

- (instancetype)initWithOriginalIcon:(NSImage*)originalIcon
{
    if ((self = [super init]))
    {
        _fOriginalIcon = [LegacyDockTile copyUsableIcon:originalIcon];
        _fBadgeView = [[BadgeView alloc] init];
        _fBadgeLabel = @"";
    }

    return self;
}

+ (NSImage*)copyUsableIcon:(NSImage*)icon
{
    NSImage* copy = icon != nil ? [icon copy] : nil;
    NSSize size = copy.size;
    if (copy != nil && size.width > 0.0 && size.height > 0.0)
    {
        return copy;
    }

    NSImage* fallback = [[NSImage alloc] initWithSize:NSMakeSize(kLegacyDockIconFallbackSize, kLegacyDockIconFallbackSize)];
    [fallback lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0.0, 0.0, kLegacyDockIconFallbackSize, kLegacyDockIconFallbackSize));
    [fallback unlockFocus];
    return fallback;
}

- (BOOL)setRatesWithDownload:(CGFloat)downloadRate upload:(CGFloat)uploadRate
{
    BOOL const changed = [self.fBadgeView setRatesWithDownload:downloadRate upload:uploadRate];
    self.fShowsDownloadSpeedBadge = downloadRate >= 0.1;
    self.fShowsUploadSpeedBadge = uploadRate >= 0.1;
    self.fShowsSpeedBadge = self.fShowsDownloadSpeedBadge || self.fShowsUploadSpeedBadge;
    return changed;
}

- (void)setBadgeLabel:(NSString*)badgeLabel
{
    _fBadgeLabel = [badgeLabel.length > 0 ? badgeLabel : @"" copy];
}

- (NSImage*)renderedIcon
{
    NSSize size = self.fOriginalIcon.size;
    if (size.width <= 0.0 || size.height <= 0.0)
    {
        size = NSMakeSize(kLegacyDockIconFallbackSize, kLegacyDockIconFallbackSize);
    }

    NSImage* renderedIcon = [[NSImage alloc] initWithSize:size];

    [renderedIcon lockFocus];
    NSRect const iconRect = NSMakeRect(0.0, 0.0, size.width, size.height);
    [self.fOriginalIcon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

    if (self.fShowsSpeedBadge)
    {
        [self drawSpeedBadgeLayerInRect:iconRect];
    }

    if (self.fBadgeLabel.length > 0)
    {
        [LegacyDockTile drawCountBadge:self.fBadgeLabel inRect:iconRect];
    }

    [renderedIcon unlockFocus];
    return renderedIcon;
}

- (void)display
{
    if (!self.fShowsSpeedBadge && self.fBadgeLabel.length == 0)
    {
        [self restoreOriginalIcon];
        return;
    }

    [NSApp setApplicationIconImage:[self renderedIcon]];
}

- (void)restoreOriginalIcon
{
    [NSApp setApplicationIconImage:self.fOriginalIcon];
}

- (void)drawSpeedBadgeLayerInRect:(NSRect)iconRect
{
    NSSize const size = iconRect.size;
    NSImage* transparentIcon = [[NSImage alloc] initWithSize:size];
    [transparentIcon lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(iconRect);
    [transparentIcon unlockFocus];

    NSImage* previousAppIcon = [[NSApp applicationIconImage] copy];
    [NSApp setApplicationIconImage:transparentIcon];

    NSImage* speedLayer = [[NSImage alloc] initWithSize:size];
    [speedLayer lockFocus];
    [self.fBadgeView setFrame:iconRect];
    [self.fBadgeView drawRect:iconRect];
    [speedLayer unlockFocus];

    [NSApp setApplicationIconImage:previousAppIcon];

    NSImage* downloadBadge = [NSImage imageNamed:@"DownloadBadge"];
    CGFloat const badgeHeight = floor(downloadBadge.size.height * kLegacyDockSpeedBadgeScale);
    CGFloat badgeBottom = NSMinY(iconRect);
    if (self.fShowsDownloadSpeedBadge)
    {
        TRDrawLegacyDockBadgeBackground(
            downloadBadge, NSMakeRect(NSMinX(iconRect), badgeBottom, NSWidth(iconRect), badgeHeight));
        badgeBottom += (downloadBadge.size.height + kLegacyDockSpeedBadgeSpacing) * kLegacyDockSpeedBadgeScale;
    }
    if (self.fShowsUploadSpeedBadge)
    {
        TRDrawLegacyDockBadgeBackground(
            [NSImage imageNamed:@"UploadBadge"], NSMakeRect(NSMinX(iconRect), badgeBottom, NSWidth(iconRect), badgeHeight));
    }

    NSRect const speedRect = NSMakeRect(
        floor(NSMidX(iconRect) - NSWidth(iconRect) * kLegacyDockSpeedBadgeScale * 0.5),
        NSMinY(iconRect),
        floor(NSWidth(iconRect) * kLegacyDockSpeedBadgeScale),
        floor(NSHeight(iconRect) * kLegacyDockSpeedBadgeScale));
    [speedLayer drawInRect:speedRect fromRect:iconRect operation:NSCompositingOperationSourceOver fraction:1.0];
}

+ (void)drawCountBadge:(NSString*)badgeLabel inRect:(NSRect)iconRect
{
    CGFloat const iconSide = MIN(NSWidth(iconRect), NSHeight(iconRect));
    CGFloat fontSize = floor(iconSide * 0.28);
    CGFloat const minFontSize = floor(iconSide * 0.17);
    CGFloat const xPadding = floor(iconSide * 0.09);
    CGFloat const yPadding = floor(iconSide * 0.03);
    CGFloat const margin = floor(iconSide * 0.045);
    CGFloat const maxWidth = NSWidth(iconRect) - margin * 2.0;

    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
    [attributes setObject:NSColor.whiteColor forKey:NSForegroundColorAttributeName];
    [attributes setObject:[NSFont boldSystemFontOfSize:fontSize] forKey:NSFontAttributeName];

    NSSize textSize = [badgeLabel sizeWithAttributes:attributes];
    while (fontSize > minFontSize && textSize.width + xPadding * 2.0 > maxWidth)
    {
        fontSize -= 1.0;
        [attributes setObject:[NSFont boldSystemFontOfSize:fontSize] forKey:NSFontAttributeName];
        textSize = [badgeLabel sizeWithAttributes:attributes];
    }

    CGFloat const badgeHeight = ceil(MAX(textSize.height + yPadding * 2.0, iconSide * 0.30));
    CGFloat const badgeWidth = ceil(MIN(maxWidth, MAX(badgeHeight, textSize.width + xPadding * 2.0)));
    NSRect badgeRect = NSMakeRect(
        NSMaxX(iconRect) - badgeWidth - margin,
        NSMaxY(iconRect) - badgeHeight - margin,
        badgeWidth,
        badgeHeight);

    NSRect shadowRect = NSOffsetRect(badgeRect, floor(iconSide * 0.025), -floor(iconSide * 0.025));
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.45] set];
    [LegacyDockTile fillPillInRect:shadowRect];

    [[NSColor colorWithCalibratedRed:0.86 green:0.0 blue:0.0 alpha:1.0] set];
    [LegacyDockTile fillPillInRect:badgeRect];

    NSRect textRect = NSMakeRect(
        NSMidX(badgeRect) - textSize.width * 0.5,
        NSMidY(badgeRect) - textSize.height * 0.5,
        textSize.width,
        textSize.height);
    [badgeLabel drawInRect:textRect withAttributes:attributes];
}

+ (void)fillPillInRect:(NSRect)rect
{
    CGFloat const diameter = NSHeight(rect);
    NSRectFill(NSInsetRect(rect, diameter * 0.5, 0.0));

    NSBezierPath* path = [NSBezierPath bezierPath];
    [path appendBezierPathWithOvalInRect:NSMakeRect(NSMinX(rect), NSMinY(rect), diameter, diameter)];
    [path appendBezierPathWithOvalInRect:NSMakeRect(NSMaxX(rect) - diameter, NSMinY(rect), diameter, diameter)];
    [path fill];
}

@end


#endif
