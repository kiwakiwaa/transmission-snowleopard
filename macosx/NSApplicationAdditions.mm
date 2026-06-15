// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "NSApplicationAdditions.h"

#include <libtransmission/macos-version.h>

@implementation NSApplication (NSApplicationAdditions)

- (BOOL)isDarkMode
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_14 && !TR_MACOS_SDK_BEFORE_10_14
    return [self.effectiveAppearance.name isEqualToString:NSAppearanceNameDarkAqua];
#else
    return NO;
#endif
}

@end
