// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface MessageWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSTableView* _fMessageTable;
    NSPopUpButton* _fLevelButton;
    NSButton* _fSaveButton;
    NSButton* _fClearButton;
    NSSearchField* _fFilterField;
    NSMutableArray* _fMessages;
    NSMutableArray* _fDisplayedMessages;
    NSDictionary* _fAttributes;
    NSTimer* _fTimer;
    NSLock* _fLock;
}
#endif

- (IBAction)changeLevel:(id)sender;
- (IBAction)changeFilter:(id)sender;
- (IBAction)clearLog:(id)sender;

- (IBAction)writeToFile:(id)sender;

@end
