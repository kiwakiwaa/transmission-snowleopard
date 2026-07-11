// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface FilePriorityCell : NSSegmentedCell
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    BOOL _hovered;
}
#endif

@property(nonatomic) BOOL hovered;

- (void)addTrackingAreasForView:(NSView*)controlView
                         inRect:(NSRect)cellFrame
                   withUserInfo:(NSDictionary*)userInfo
                  mouseLocation:(NSPoint)mouseLocation;

@end
