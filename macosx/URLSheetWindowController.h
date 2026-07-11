// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface URLSheetWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSTextField* _fLabelField;
    IBOutlet NSTextField* _fTextField;
    IBOutlet NSButton* _fOpenButton;
    IBOutlet NSButton* _fCancelButton;
}
#endif

@property(nonatomic, readonly) NSString* urlString;

- (instancetype)init;

- (IBAction)openURLEndSheet:(id)sender;
- (IBAction)openURLCancelEndSheet:(id)sender;

@end
