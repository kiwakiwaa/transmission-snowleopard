// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#import "LegacyFoundationTypes.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
@interface TRProgressGradient : NSObject
{
    CGFloat fComponents[12];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (void)drawInRect:(NSRect)rect angle:(CGFloat)angle;

@end
#else
typedef NSGradient TRProgressGradient;
#endif

@interface ProgressGradients : NSObject

@property(nonatomic, class, readonly) TRProgressGradient* progressWhiteGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressGrayGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressLightGrayGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressBlueGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressDarkBlueGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressGreenGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressLightGreenGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressDarkGreenGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressRedGradient;
@property(nonatomic, class, readonly) TRProgressGradient* progressYellowGradient;

@end
