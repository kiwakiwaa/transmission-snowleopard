// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface TrackerCell : NSActionCell
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSMutableDictionary* _fNameAttributes;
    NSMutableDictionary* _fStatusAttributes;
}
#endif

@end
