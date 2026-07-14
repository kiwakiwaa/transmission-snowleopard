// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_5 || TR_MACOS_DEPLOYMENT_BEFORE_10_5

@interface LegacyAnimationContext : NSObject<NSCopying>
{
  @private
    NSTimeInterval _duration;
    void* _completionHandler;
    BOOL _allowsImplicitAnimation;
}

@property(nonatomic) NSTimeInterval duration;
@property(nonatomic, copy) void (^completionHandler)(void);
@property(nonatomic) BOOL allowsImplicitAnimation;

+ (void)beginGrouping;
+ (void)endGrouping;
+ (LegacyAnimationContext*)currentContext;
+ (void)runAnimationGroup:(__unsafe_unretained void (^)(LegacyAnimationContext* context))changes
        completionHandler:(__unsafe_unretained void (^)(void))completionHandler;

@end

#define NSAnimationContext LegacyAnimationContext

#endif
