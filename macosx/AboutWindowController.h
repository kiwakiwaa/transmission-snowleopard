// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface AboutWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSTextView* _fTextView;
    IBOutlet NSTextView* _fLicenseView;
    IBOutlet NSTextField* _fVersionField;
    IBOutlet NSTextField* _fCopyrightField;
    IBOutlet NSButton* _fLicenseButton;
    IBOutlet NSButton* _fLicenseCloseButton;
    IBOutlet NSPanel* _fLicenseSheet;
}
#endif

@property(nonatomic, class, readonly) AboutWindowController* aboutController;

- (IBAction)showLicense:(id)sender;
- (IBAction)hideLicense:(id)sender;

@end
