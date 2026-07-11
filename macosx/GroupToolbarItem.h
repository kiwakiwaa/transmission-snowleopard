// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface GroupToolbarItem : NSToolbarItemGroup
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    BOOL _fEnabled;
    BOOL _fHasEnabledState;
}
#endif

- (void)createMenu:(NSArray*)labels;

@end
