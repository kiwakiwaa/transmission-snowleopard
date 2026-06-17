// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "TorrentCellRevealButton.h"
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
#import "LegacyWeakReference.h"
#endif
#import "TorrentTableView.h"
#import "TorrentCell.h"

@interface TorrentCellRevealButton ()
@property(nonatomic) NSTrackingArea* fTrackingArea;
@property(nonatomic, copy) NSString* revealImageString;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
@property(nonatomic) IBOutlet TorrentCell* torrentCell;
#else
@property(nonatomic, TR_OBJC_WEAK) IBOutlet TorrentCell* torrentCell;
#endif
@property(nonatomic, readonly) TorrentTableView* torrentTableView;
@end

@implementation TorrentCellRevealButton
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
{
    LegacyWeakReference* _torrentCellWeakReference;
}

// Lion cannot form native weak references to NSTableCellView subclasses.
TR_LEGACY_WEAK_REFERENCE_ACCESSORS(TorrentCell, torrentCell, setTorrentCell, _torrentCellWeakReference)
#endif

- (TorrentTableView*)torrentTableView
{
    return self.torrentCell.fTorrentTableView;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.revealImageString = @"RevealOff";
    [self updateImage];
}

- (void)mouseEntered:(NSEvent*)event
{
    [super mouseEntered:event];
    self.revealImageString = @"RevealHover";
    [self updateImage];

    [self.torrentTableView hoverEventBeganForView:self];
}

- (void)mouseExited:(NSEvent*)event
{
    [super mouseExited:event];
    self.revealImageString = @"RevealOff";
    [self updateImage];

    [self.torrentTableView hoverEventEndedForView:self];
}

- (void)mouseDown:(NSEvent*)event
{
    //when filterbar is shown, we need to remove focus otherwise action fails
    [self.window makeFirstResponder:self.torrentTableView];

    [super mouseDown:event];
    self.revealImageString = @"RevealOn";
    [self updateImage];
}

- (void)updateImage
{
    NSImage* revealImage = [NSImage imageNamed:self.revealImageString];
    self.image = revealImage;
    self.needsDisplay = YES;
}

- (void)updateTrackingAreas
{
    if (self.fTrackingArea != nil)
    {
        [self removeTrackingArea:self.fTrackingArea];
    }

    NSTrackingAreaOptions opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    self.fTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:opts owner:self userInfo:nil];
    [self addTrackingArea:self.fTrackingArea];
}

@end
