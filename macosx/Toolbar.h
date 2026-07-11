// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface Toolbar : NSToolbar
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    BOOL _isRunningCustomizationPalette;
}
#endif

@property(readonly) BOOL isRunningCustomizationPalette;

@end
