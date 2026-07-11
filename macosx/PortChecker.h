// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PortStatus) { //
    PortStatusChecking,
    PortStatusOpen,
    PortStatusClosed,
    PortStatusError
};

@protocol PortCheckerDelegate;
@class LegacyWeakReference;
@class TRURLRequestTask;

@interface PortChecker : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_7 && TR_MACOS_DEPLOYMENT_BEFORE_10_8
    id<PortCheckerDelegate> _fDelegate;
    LegacyWeakReference* _delegateWeakReference;
#else
    __weak id<PortCheckerDelegate> _fDelegate;
#endif
    PortStatus _fStatus;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSURLSession* _fSession;
    NSURLSessionDataTask* _fTask;
#else
    TRURLRequestTask* _fTask;
#endif
    NSTimer* _fTimer;
}
#endif

@property(nonatomic, readonly) PortStatus status;

- (instancetype)initForPort:(NSInteger)portNumber delay:(BOOL)delay withDelegate:(id<PortCheckerDelegate>)delegate;
- (void)cancelProbe;

@end

@protocol PortCheckerDelegate

- (void)portCheckerDidFinishProbing:(PortChecker*)portChecker;

@end

NS_ASSUME_NONNULL_END
