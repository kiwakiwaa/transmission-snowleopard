// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_5 || TR_MACOS_DEPLOYMENT_BEFORE_10_5
@interface GroupToolbarItem : NSToolbarItem
#else
@interface GroupToolbarItem : NSToolbarItemGroup
#endif
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    BOOL _fEnabled;
    BOOL _fHasEnabledState;
#if TR_MACOS_SDK_BEFORE_10_5 || TR_MACOS_DEPLOYMENT_BEFORE_10_5
    NSArray* _subitems;
#endif
}
#endif

#if TR_MACOS_SDK_BEFORE_10_5 || TR_MACOS_DEPLOYMENT_BEFORE_10_5
@property(nonatomic, copy) NSArray* subitems;
#endif

- (void)createMenu:(NSArray*)labels;

@end
