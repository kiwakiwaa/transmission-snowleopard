// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface BlocklistScheduler : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSTimer* _fTimer;
}
#endif

@property(nonatomic, class, readonly) BlocklistScheduler* scheduler;

- (void)updateSchedule;
- (void)cancelSchedule;

@end
