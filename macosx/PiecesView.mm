// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#include <libtransmission/transmission.h>

#import "PiecesView.h"
#import "CocoaCompatibility.h"
#import "Torrent.h"
#import "InfoWindowController.h"
#import "NSApplicationAdditions.h"

static NSInteger const kMaxAcross = 18;
static NSInteger const kMaxCells = kMaxAcross * kMaxAcross;

static CGFloat const kBetweenPadding = 1.0;

static int8_t const kHighPeers = 10;

static NSColor* DoneColor(void)
{
    return TRSystemBlueColor();
}

static NSColor* BlinkColor(void)
{
    return TRSystemOrangeColor();
}

static NSColor* HighColor(void)
{
    return TRSystemGreenColor(); // high availability
}

typedef struct PieceInfo
{
    int8_t available[kMaxCells];
    float complete[kMaxCells];
} PieceInfo;

@interface PiecesView ()
@end

@implementation PiecesView
{
    PieceInfo fPieceInfo;
    NSString* fRenderedHashString;
}

- (NSColor*)backgroundColor
{
    return [NSApp isDarkMode] ? NSColor.blackColor : NSColor.whiteColor;
}

- (BOOL)isCompletenessDone:(float)val
{
    return val >= 1.0F;
}

- (BOOL)isCompletenessNone:(float)val
{
    return val <= 0.0F;
}

- (NSColor*)completenessColor:(float)oldVal newVal:(float)newVal noBlink:(BOOL)noBlink
{
    if ([self isCompletenessDone:newVal])
    {
        return noBlink || [self isCompletenessDone:oldVal] ? DoneColor() : BlinkColor();
    }

    if ([self isCompletenessNone:newVal])
    {
        return noBlink || [self isCompletenessNone:oldVal] ? [self backgroundColor] : BlinkColor();
    }

    return [[self backgroundColor] blendedColorWithFraction:newVal ofColor:DoneColor()];
}

- (BOOL)isAvailabilityDone:(uint8_t)val
{
    return val == (uint8_t)-1;
}

- (BOOL)isAvailabilityNone:(uint8_t)val
{
    return val == 0;
}

- (BOOL)isAvailabilityHigh:(uint8_t)val
{
    return val >= kHighPeers;
}

- (NSColor*)availabilityColor:(int8_t)oldVal newVal:(int8_t)newVal noBlink:(bool)noBlink
{
    if ([self isAvailabilityDone:newVal])
    {
        return noBlink || [self isAvailabilityDone:oldVal] ? DoneColor() : BlinkColor();
    }

    if ([self isAvailabilityNone:newVal])
    {
        return noBlink || [self isAvailabilityNone:oldVal] ? [self backgroundColor] : BlinkColor();
    }

    if ([self isAvailabilityHigh:newVal])
    {
        return noBlink || [self isAvailabilityHigh:oldVal] ? HighColor() : BlinkColor();
    }

    CGFloat percent = CGFloat(newVal) / kHighPeers;
    return [[self backgroundColor] blendedColorWithFraction:percent ofColor:HighColor()];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor.controlTextColor colorWithAlphaComponent:0.2] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.torrent = nil;
}

- (void)viewDidChangeEffectiveAppearance
{
    self.torrent = _torrent;
    [self updateView];
}

- (void)dealloc
{
}

- (void)setTorrent:(Torrent*)torrent
{
    _torrent = (torrent && !torrent.magnet) ? torrent : nil;
    self.image = [[NSImage alloc] initWithSize:self.bounds.size];

    [self clearView];
    self.needsDisplay = YES;
}

- (void)clearView
{
    fRenderedHashString = nil;
    memset(&fPieceInfo, 0, sizeof(PieceInfo));
}

- (void)updateView
{
    if (!self.torrent)
    {
        return;
    }

    // get the previous state
    PieceInfo const oldInfo = fPieceInfo;
    BOOL const first = ![self.torrent.hashString isEqualToString:fRenderedHashString];

    // get the current state
    BOOL const showAvailability = [NSUserDefaults.standardUserDefaults boolForKey:@"PiecesViewShowAvailability"];
    int const numCells = static_cast<int>(MIN(_torrent.pieceCount, kMaxCells));
    PieceInfo info;
    [self.torrent getAvailability:info.available size:numCells];
    [self.torrent getAmountFinished:info.complete size:numCells];

    // compute bounds and color of each cell
    int const across = static_cast<int>(ceil(sqrt(numCells)));
    CGFloat const fullWidth = self.bounds.size.width;
    NSInteger const cellWidth = (NSInteger)((fullWidth - (across + 1) * kBetweenPadding) / across);
    NSInteger const extraBorder = (NSInteger)((fullWidth - ((cellWidth + kBetweenPadding) * across + kBetweenPadding)) / 2);
    NSMutableArray* cellBounds = [NSMutableArray arrayWithCapacity:numCells];
    NSMutableArray* cellColors = [NSMutableArray arrayWithCapacity:numCells];
    for (int index = 0; index < numCells; index++)
    {
        int const row = index / across;
        int const col = index % across;

        [cellBounds addObject:[NSValue valueWithRect:NSMakeRect(
                                                        col * (cellWidth + kBetweenPadding) + kBetweenPadding + extraBorder,
                                                        fullWidth - (row + 1) * (cellWidth + kBetweenPadding) - extraBorder,
                                                        cellWidth,
                                                        cellWidth)]];

        [cellColors addObject:showAvailability ? [self availabilityColor:oldInfo.available[index] newVal:info.available[index] noBlink:first] :
                                                 [self completenessColor:oldInfo.complete[index] newVal:info.complete[index] noBlink:first]];
    }

    // build an image with the cells
    if (numCells > 0)
    {
        self.image = [NSImage imageWithSize:self.bounds.size flipped:NO drawingHandler:^BOOL(NSRect /*dstRect*/) {
            NSRect cFillRects[kMaxCells];
            for (int i = 0; i < numCells; ++i)
            {
                cFillRects[i] = [(NSValue*)[cellBounds objectAtIndex:i] rectValue];
            }
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
            NSColor* __unsafe_unretained cFillColors[kMaxCells];
#else
            NSColor* cFillColors[kMaxCells];
#endif
            for (int i = 0; i < numCells; ++i)
            {
                cFillColors[i] = cellColors[i];
            }
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
            for (int i = 0; i < numCells; ++i)
            {
                [cFillColors[i] setFill];
                NSRectFill(cFillRects[i]);
            }
#else
            NSRectFillListWithColors(cFillRects, cFillColors, numCells);
#endif
            return YES;
        }];
        self.needsDisplay = YES;
    }

    // save the current state so we can compare it later
    fPieceInfo = info;
    fRenderedHashString = self.torrent.hashString;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event
{
    return YES;
}

- (void)mouseDown:(NSEvent*)event
{
    if (self.torrent)
    {
        BOOL const availability = ![NSUserDefaults.standardUserDefaults boolForKey:@"PiecesViewShowAvailability"];
        [NSUserDefaults.standardUserDefaults setBool:availability forKey:@"PiecesViewShowAvailability"];

        [self sendAction:self.action to:self.target];
    }

    [super mouseDown:event];
}

@end
