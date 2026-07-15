// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
@interface NSDateFormatter (TRRelativeDateFormatting)

@property(nonatomic) BOOL doesRelativeDateFormatting;

@end
#endif

NSString* TRTimeRemainingString(NSTimeInterval interval);
NSString* TRStatsDurationString(NSTimeInterval interval);
NSString* TRTrackerCountdownString(NSTimeInterval interval);
NSString* TRShortDurationString(NSTimeInterval interval);
