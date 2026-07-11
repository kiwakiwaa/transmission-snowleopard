// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#ifndef __has_include
#define __has_include(x) 0
#endif

#if __has_include(<os/log.h>)
#include <os/log.h>
#else
typedef void* os_log_t;
#endif

@protocol PowerManagerDelegate<NSObject>

- (void)systemWillSleep;
- (void)systemDidWakeUp;

@end

@interface PowerManager : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    __weak id<PowerManagerDelegate> _delegate;
    os_log_t _log;
    BOOL _listening;
    id<NSObject> _noNapActivity;
    id<NSObject> _noSleepActivity;
}
#endif

@property(nonatomic, class, readonly) PowerManager* shared;

@property(nonatomic, weak) id<PowerManagerDelegate> delegate;
@property(nonatomic) BOOL shouldPreventSleep;

- (instancetype)init NS_UNAVAILABLE;

- (void)start;
- (void)stop;

@end
