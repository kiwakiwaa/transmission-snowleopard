// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface BadgeView : NSView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSMutableDictionary* _fAttributes;
    CGFloat _fDownloadRate;
    CGFloat _fUploadRate;
}
#endif

- (BOOL)setRatesWithDownload:(CGFloat)downloadRate upload:(CGFloat)uploadRate;

@end
