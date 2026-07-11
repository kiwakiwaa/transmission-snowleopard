// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface DragOverlayView : NSView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSImage* _fBadge;
    NSDictionary* _fMainLineAttributes;
    NSDictionary* _fSubLineAttributes;
}
#endif

- (void)setOverlay:(NSImage*)icon mainLine:(NSString*)mainLine subLine:(NSString*)subLine;

@end
