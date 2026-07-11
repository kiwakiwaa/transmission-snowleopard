// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "PortChecker.h"
#import "CocoaCompatibility.h"

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
#import "LegacyWeakReference.h"
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
#import "LegacyURLRequest.h"
#endif

static NSTimeInterval const kCheckFireInterval = 3.0;

@interface PortChecker ()

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
@property(nonatomic) id<PortCheckerDelegate> fDelegate;
#else
@property(nonatomic, weak) id<PortCheckerDelegate> fDelegate;
#endif
@property(nonatomic) PortStatus fStatus;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
@property(nonatomic) NSURLSession* fSession;
@property(nonatomic) NSURLSessionDataTask* fTask;
#else
@property(nonatomic) TRURLRequestTask* fTask;
#endif

@property(nonatomic) NSTimer* fTimer;

@end

@implementation PortChecker
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
{
    LegacyWeakReference* _delegateWeakReference;
}

// Lion rejects native weak references to the KVO subclass of PrefsController.
TR_LEGACY_WEAK_REFERENCE_ACCESSORS(NSObject<PortCheckerDelegate>, fDelegate, setFDelegate, _delegateWeakReference)
#else
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fDelegate = _fDelegate;
#endif
#endif
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fStatus = _fStatus;
#endif
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fSession = _fSession;
#endif
#endif
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fTask = _fTask;
@synthesize fTimer = _fTimer;
#endif

- (instancetype)initForPort:(NSInteger)portNumber delay:(BOOL)delay withDelegate:(id<PortCheckerDelegate>)delegate
{
    if ((self = [super init]))
    {
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
        _fSession = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:nil
                                             delegateQueue:nil];
#endif
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
        self.fDelegate = delegate;
#else
        _fDelegate = delegate;
#endif

        _fStatus = PortStatusChecking;

        __weak __auto_type weakSelf = self;
        _fTimer = TRScheduledTimerWithTimeInterval(kCheckFireInterval, NO, ^(NSTimer* _Nonnull) {
            [weakSelf startProbe:portNumber];
        });

        if (!delay)
        {
            [_fTimer fire];
        }
    }

    return self;
}

- (void)dealloc
{
    [self cancelProbe];
}

- (PortStatus)status
{
    return self.fStatus;
}

- (void)cancelProbe
{
    [self.fTimer invalidate];
    self.fTimer = nil;

    [self.fTask cancel];
    self.fTask = nil;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    [self.fSession invalidateAndCancel];
    self.fSession = nil;
#endif
}

#pragma mark - Private

- (void)startProbe:(NSInteger)port
{
    self.fTimer = nil;

    NSString* urlString = [NSString stringWithFormat:@"https://portcheck.transmissionbt.com/%ld", port];
    NSURLRequest* portProbeRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                  timeoutInterval:15.0];

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    self.fTask = [self.fSession dataTaskWithRequest:portProbeRequest completionHandler:^(NSData* data, NSURLResponse*, NSError* error) {
#else
    self.fTask = [TRURLRequestTask dataTaskWithRequest:portProbeRequest completionHandler:^(NSData* data, NSURLResponse*, NSError* error) {
#endif
        self.fTask = nil;
        if (error)
        {
            NSLog(@"Unable to get port status: connection failed (%@)", error.localizedDescription);
            [self callBackWithStatus:PortStatusError];
            return;
        }
        NSString* probeString = [[NSString alloc] initWithData:data ?: [NSData data] encoding:NSUTF8StringEncoding];
        if (!probeString)
        {
            NSLog(@"Unable to get port status: invalid data received");
            [self callBackWithStatus:PortStatusError];
        }
        else if ([probeString isEqualToString:@"1"])
        {
            [self callBackWithStatus:PortStatusOpen];
        }
        else if ([probeString isEqualToString:@"0"])
        {
            [self callBackWithStatus:PortStatusClosed];
        }
        else
        {
            NSLog(@"Unable to get port status: invalid response (%@)", probeString);
            [self callBackWithStatus:PortStatusError];
        }
    }];
    [self.fTask resume];
}

- (void)callBackWithStatus:(PortStatus)status
{
    self.fStatus = status;

    __auto_type delegate = self.fDelegate;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate portCheckerDidFinishProbing:self];
    });
}

@end
