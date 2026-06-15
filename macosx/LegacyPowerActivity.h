// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
typedef NSUInteger NSActivityOptions;
#define NSActivityIdleSystemSleepDisabled 0
#define NSActivityUserInitiatedAllowingIdleSystemSleep 0
#define NSProcessInfoPowerStateDidChangeNotification @"NSProcessInfoPowerStateDidChangeNotification"

@interface NSProcessInfo (TransmissionActivityCompatibility)
- (id<NSObject>)beginActivityWithOptions:(NSActivityOptions)options reason:(NSString*)reason;
- (void)endActivity:(id<NSObject>)activity;
- (BOOL)lowPowerModeEnabled;
@end
#endif
