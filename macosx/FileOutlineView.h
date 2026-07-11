// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface FileOutlineView : NSOutlineView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSInteger _hoveredRow;
}
#endif

@property(nonatomic, readonly) NSInteger hoveredRow;

- (NSRect)iconRectForRow:(NSInteger)row;

@end
