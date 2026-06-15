// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "PortChecker.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
#import "LegacyURLRequest.h"
#endif

static NSTimeInterval const kCheckFireInterval = 3.0;

@interface PortChecker ()

@property(nonatomic, TR_OBJC_WEAK) NSObject<PortCheckerDelegate>* fDelegate;
@property(nonatomic) PortStatus fStatus;

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
@property(nonatomic) NSURLSession* fSession;
@property(nonatomic) NSURLSessionDataTask* fTask;
#else
@property(nonatomic) TRURLRequestTask* fTask;
#endif

@property(nonatomic) NSTimer* fTimer;

@end

@implementation PortChecker

- (instancetype)initForPort:(NSInteger)portNumber delay:(BOOL)delay withDelegate:(NSObject<PortCheckerDelegate>*)delegate
{
    if ((self = [super init]))
    {
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
        _fSession = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:nil
                                             delegateQueue:nil];
#endif
        _fDelegate = delegate;

        _fStatus = PortStatusChecking;

        _fTimer = [NSTimer scheduledTimerWithTimeInterval:kCheckFireInterval target:self selector:@selector(startProbe:)
                                                 userInfo:@(portNumber)
                                                  repeats:NO];
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
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    [self.fSession invalidateAndCancel];
    self.fSession = nil;
#endif
}

#pragma mark - Private

- (void)startProbe:(NSTimer*)timer
{
    self.fTimer = nil;

    NSString* urlString = [NSString stringWithFormat:@"https://portcheck.transmissionbt.com/%ld", [(NSNumber*)timer.userInfo integerValue]];
    NSURLRequest* portProbeRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                  timeoutInterval:15.0];

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
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

    NSObject<PortCheckerDelegate>* delegate = self.fDelegate;
    [delegate performSelectorOnMainThread:@selector(portCheckerDidFinishProbing:) withObject:self waitUntilDone:NO];
}

@end
