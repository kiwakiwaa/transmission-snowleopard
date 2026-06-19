// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_10
@interface NSTitlebarAccessoryViewController : NSViewController
@property(nonatomic) NSLayoutAttribute layoutAttribute;
@property(nonatomic, getter=isHidden) BOOL hidden;
@property(nonatomic) BOOL automaticallyAdjustsSize;
@end

@interface NSWindow (TransmissionTitlebarAccessoryCompatibility)
- (void)addTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController*)controller;
@end
#endif

void TRLayoutLegacyTitlebarAccessoryWindow(NSWindow* window);
BOOL TRTitlebarAccessoryIsHidden(NSWindow* window, NSTitlebarAccessoryViewController* controller);
void TRTitlebarAccessorySetHidden(NSWindow* window, NSTitlebarAccessoryViewController* controller, BOOL hidden);
void TRApplyTitlebarAccessoryVisibility(NSWindow* window, NSArray* orderedControllers);
