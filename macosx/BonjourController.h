// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

@interface BonjourController : NSObject<NSNetServiceDelegate>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSNetService* _fService;
}
#endif

@property(nonatomic, class, readonly) BonjourController* defaultController;
@property(nonatomic, class, readonly) BOOL defaultControllerExists;

- (void)startWithPort:(int)port;
- (void)stop;

@end
