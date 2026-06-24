// This file Copyright © 2023 Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#ifndef TR_ENABLE_SPARKLE
#define TR_ENABLE_SPARKLE 1
#endif

#include <libtransmission/macos-version.h>

#if TR_ENABLE_SPARKLE
#if TR_MACOS_SDK_BEFORE_10_11
#import "SparkleCompatibility.h"
#else
#import <Sparkle/SUVersionComparisonProtocol.h>
#endif
#else
@protocol SUVersionComparison<NSObject>
- (NSComparisonResult)compareVersion:(NSString*)versionA toVersion:(NSString*)versionB;
@end

#endif

NS_ASSUME_NONNULL_BEGIN

@interface VersionComparator : NSObject<SUVersionComparison>

@end

NS_ASSUME_NONNULL_END
