// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/transmission.h>

@interface StatusBarController : NSTitlebarAccessoryViewController<NSMenuItemValidation>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSButton* _fStatusButton;
    NSTextField* _fTotalDLField;
    NSTextField* _fTotalULField;
    NSImageView* _fTotalDLImageView;
    NSImageView* _fTotalULImageView;
    tr_session* _fLib;
    CGFloat _fPreviousDownloadRate;
    CGFloat _fPreviousUploadRate;
}
#endif

- (instancetype)initWithLib:(tr_session*)lib;

- (void)updateWithDownload:(CGFloat)dlRate upload:(CGFloat)ulRate;

- (void)updateSpeedFieldsToolTips;

@end
