// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface FilterButton : NSButton
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSUInteger _count;
}
#endif

@property(nonatomic) NSUInteger count;

@end
