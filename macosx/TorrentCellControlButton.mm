// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "TorrentCellControlButton.h"
#import "CocoaCompatibility.h"
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
#import "LegacyWeakReference.h"
#endif
#import "TorrentTableView.h"
#import "Torrent.h"
#import "TorrentCell.h"

@interface TorrentCellControlButton ()
@property(nonatomic) NSTrackingArea* fTrackingArea;
@property(nonatomic, copy) NSString* controlImageSuffix;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
@property(nonatomic) IBOutlet TorrentCell* torrentCell;
#else
@property(nonatomic, weak) IBOutlet TorrentCell* torrentCell;
#endif
@property(nonatomic, readonly) TorrentTableView* torrentTableView;
@end

@implementation TorrentCellControlButton
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
{
    LegacyWeakReference* _torrentCellWeakReference;
}

// Lion cannot form native weak references to NSTableCellView subclasses.
TR_LEGACY_WEAK_REFERENCE_ACCESSORS(TorrentCell, torrentCell, setTorrentCell, _torrentCellWeakReference)
#endif

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fTrackingArea = _fTrackingArea;
@synthesize controlImageSuffix = _controlImageSuffix;
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7 || !TR_MACOS_DEPLOYMENT_BEFORE_10_8
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize torrentCell = _torrentCell;
#endif
#endif

+ (NSImage*)imageForTorrent:(Torrent*)torrent suffix:(NSString*)suffix optionKeyDown:(BOOL)optionKeyDown
{
    NSString* imageName;
    if (torrent.active)
    {
        imageName = @"Pause";
    }
    else if (optionKeyDown)
    {
        imageName = @"ResumeNoWait";
    }
    else if (torrent.waitingToStart)
    {
        imageName = @"Pause";
    }
    else
    {
        imageName = @"Resume";
    }

    return [NSImage imageNamed:[imageName stringByAppendingString:suffix]];
}

+ (NSString*)descriptionForTorrent:(Torrent*)torrent optionKeyDown:(BOOL)optionKeyDown
{
    if (torrent.active)
    {
        return NSLocalizedString(@"Pause the transfer", "Torrent Table -> tooltip");
    }
    if (optionKeyDown)
    {
        return NSLocalizedString(@"Resume the transfer right away", "Torrent cell -> button info");
    }
    if (torrent.waitingToStart)
    {
        return NSLocalizedString(@"Stop waiting to start", "Torrent cell -> button info");
    }
    return NSLocalizedString(@"Resume the transfer", "Torrent cell -> button info");
}

- (TorrentTableView*)torrentTableView
{
    return self.torrentCell.fTorrentTableView;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.controlImageSuffix = @"Off";
    [self updateImage];
}

- (void)resetImage
{
    self.controlImageSuffix = @"Off";
    [self updateImage];
}

- (void)mouseEntered:(NSEvent*)event
{
    [super mouseEntered:event];
    self.controlImageSuffix = @"Hover";
    [self updateImage];

    [self.torrentTableView hoverEventBeganForView:self];
}

- (void)mouseExited:(NSEvent*)event
{
    [super mouseExited:event];
    self.controlImageSuffix = @"Off";
    [self updateImage];

    [self.torrentTableView hoverEventEndedForView:self];
}

- (void)mouseDown:(NSEvent*)event
{
    //when filterbar is shown, we need to remove focus otherwise action fails
    [self.window makeFirstResponder:self.torrentTableView];

    [super mouseDown:event];
    self.controlImageSuffix = @"On";
    [self updateImage];

    [self.torrentTableView hoverEventEndedForView:self];
}

- (void)updateImage
{
    Torrent* torrent = [self.torrentTableView itemAtRow:[self.torrentTableView rowForView:self]];
    self.image = [TorrentCellControlButton imageForTorrent:torrent
                                                   suffix:self.controlImageSuffix
                                            optionKeyDown:([NSAppCurrentEvent() modifierFlags] & NSEventModifierFlagOption) != 0];
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
