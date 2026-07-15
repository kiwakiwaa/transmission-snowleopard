// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "BlocklistScheduler.h"
#import "BlocklistDownloader.h"
#import "CocoaCompatibility.h"

//thirty second delay before running after option is changed
static NSTimeInterval const kSmallDelay = 30;

//update one week after previous update
static NSTimeInterval const kFullWait = 60 * 60 * 24 * 7;

@interface BlocklistScheduler ()

@property(nonatomic) NSTimer* fTimer;

@end

@implementation BlocklistScheduler

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fTimer = _fTimer;
#endif

+ (BlocklistScheduler*)scheduler
{
    static BlocklistScheduler* scheduler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scheduler = [[BlocklistScheduler alloc] init];
    });
    return scheduler;
}

- (void)updateSchedule
{
    if (BlocklistDownloader.isRunning)
        return;

    [self cancelSchedule];

    NSString* blocklistURL;
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"BlocklistNew"] ||
        !((blocklistURL = [NSUserDefaults.standardUserDefaults stringForKey:@"BlocklistURL"]) && ![blocklistURL isEqualToString:@""]) ||
        ![NSUserDefaults.standardUserDefaults boolForKey:@"BlocklistAutoUpdate"])
    {
        return;
    }

    NSDate* lastUpdateDate = [NSUserDefaults.standardUserDefaults objectForKey:@"BlocklistNewLastUpdate"];
    if (lastUpdateDate)
    {
        lastUpdateDate = TRDateByAddingTimeInterval(lastUpdateDate, kFullWait);
    }
    NSDate* closeDate = [NSDate dateWithTimeIntervalSinceNow:kSmallDelay];

    NSDate* useDate = lastUpdateDate ? [lastUpdateDate laterDate:closeDate] : closeDate;

    __weak __auto_type weakSelf = self;
    self.fTimer = TRTimerWithFireDate(useDate, 0, NO, ^(NSTimer* _Nonnull) {
        [weakSelf runUpdater];
    });

    //current run loop usually means a second update won't work
    NSRunLoop* loop = TRMainRunLoop();
    [loop addTimer:self.fTimer forMode:NSDefaultRunLoopMode];
    [loop addTimer:self.fTimer forMode:NSModalPanelRunLoopMode];
    [loop addTimer:self.fTimer forMode:NSEventTrackingRunLoopMode];
}

- (void)cancelSchedule
{
    [self.fTimer invalidate];
    self.fTimer = nil;
}

#pragma mark - Private

- (void)runUpdater
{
    self.fTimer = nil;
    [BlocklistDownloader downloader];
}

@end
