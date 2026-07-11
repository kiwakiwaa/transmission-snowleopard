// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/transmission.h>

@interface GlobalOptionsPopoverViewController : NSViewController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    tr_session* _fHandle;
    NSUserDefaults* _fDefaults;
    IBOutlet NSTextField* _fUploadLimitField;
    IBOutlet NSTextField* _fDownloadLimitField;
    IBOutlet NSTextField* _fRatioStopField;
    IBOutlet NSTextField* _fIdleStopField;
    NSString* _fInitialString;
}
#endif

- (instancetype)initWithHandle:(tr_session*)handle;

- (IBAction)updatedDisplayString:(id)sender;

- (IBAction)setDownSpeedSetting:(id)sender;
- (IBAction)setDownSpeedLimit:(id)sender;

- (IBAction)setUpSpeedSetting:(id)sender;
- (IBAction)setUpSpeedLimit:(id)sender;

- (IBAction)setRatioStopSetting:(id)sender;
- (IBAction)setRatioStopLimit:(id)sender;

- (IBAction)setIdleStopSetting:(id)sender;
- (IBAction)setIdleStopLimit:(id)sender;

@end
