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
    NSImage* controlImage;
    Torrent* torrent = [self.torrentTableView itemAtRow:[self.torrentTableView rowForView:self]];
    if (torrent.active)
    {
        controlImage = [NSImage imageNamed:[@"Pause" stringByAppendingString:self.controlImageSuffix]];
    }
    else
    {
        if ([NSAppCurrentEvent() modifierFlags] & NSEventModifierFlagOption)
        {
            controlImage = [NSImage imageNamed:[@"ResumeNoWait" stringByAppendingString:self.controlImageSuffix]];
        }
        else if (torrent.waitingToStart)
        {
            controlImage = [NSImage imageNamed:[@"Pause" stringByAppendingString:self.controlImageSuffix]];
        }
        else
        {
            controlImage = [NSImage imageNamed:[@"Resume" stringByAppendingString:self.controlImageSuffix]];
        }
    }
    self.image = controlImage;
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
