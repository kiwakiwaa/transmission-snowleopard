// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "InfoWindow.h"

@interface InfoWindow ()

#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
@property(nonatomic) BOOL settingAnchoredFrame;
#endif

@end

@implementation InfoWindow

#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
- (NSRect)anchoredLiveResizeFrame:(NSRect)frameRect
{
    if (!self.settingAnchoredFrame && self.anchorsLiveResizeTopEdge && self.liveResizeTopEdge > 0.0)
    {
        // 10.7-10.9 AppKit can re-anchor fixed-height changes during
        // side-edge live resize. Clamp before super stores/draws that frame.
        frameRect.origin.y = self.liveResizeTopEdge - NSHeight(frameRect);
    }

    return frameRect;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag
{
    NSRect const anchoredFrame = [self anchoredLiveResizeFrame:frameRect];
    self.settingAnchoredFrame = YES;
    [super setFrame:anchoredFrame display:flag];
    self.settingAnchoredFrame = NO;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)displayFlag animate:(BOOL)animateFlag
{
    NSRect const anchoredFrame = [self anchoredLiveResizeFrame:frameRect];
    self.settingAnchoredFrame = YES;
    [super setFrame:anchoredFrame display:displayFlag animate:animateFlag];
    self.settingAnchoredFrame = NO;
}
#endif

@end
