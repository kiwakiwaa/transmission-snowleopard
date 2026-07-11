// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface StatsWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSTextField* _fUploadedField;
    IBOutlet NSTextField* _fUploadedAllField;
    IBOutlet NSTextField* _fDownloadedField;
    IBOutlet NSTextField* _fDownloadedAllField;
    IBOutlet NSTextField* _fRatioField;
    IBOutlet NSTextField* _fRatioAllField;
    IBOutlet NSTextField* _fTimeField;
    IBOutlet NSTextField* _fTimeAllField;
    IBOutlet NSTextField* _fNumOpenedField;
    IBOutlet NSTextField* _fUploadedLabelField;
    IBOutlet NSTextField* _fDownloadedLabelField;
    IBOutlet NSTextField* _fRatioLabelField;
    IBOutlet NSTextField* _fTimeLabelField;
    IBOutlet NSTextField* _fNumOpenedLabelField;
    IBOutlet NSButton* _fResetButton;
    NSTimer* _fTimer;
}
#endif

@property(nonatomic, class, readonly) StatsWindowController* statsWindow;

- (IBAction)resetStats:(id)sender;

@end
