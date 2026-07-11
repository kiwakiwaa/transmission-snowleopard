// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#import <AppKit/AppKit.h>
@class NSPredicateEditor;
#else
#import <Foundation/Foundation.h>
#endif

@interface GroupsPrefsController : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSTableView* _fTableView;
    IBOutlet NSSegmentedControl* _fAddRemoveControl;
    IBOutlet NSColorWell* _fSelectedColorView;
    IBOutlet NSTextField* _fSelectedColorNameField;
    IBOutlet NSButton* _fCustomLocationEnableCheck;
    IBOutlet NSPopUpButton* _fCustomLocationPopUp;
    IBOutlet NSButton* _fAutoAssignRulesEnableCheck;
    IBOutlet NSButton* _fAutoAssignRulesEditButton;
    IBOutlet NSPopUpButton* _fAnnouncedClientIdentityPopUp;
    IBOutlet NSWindow* _groupRulesSheetWindow;
    IBOutlet NSPredicateEditor* __weak _ruleEditor;
    IBOutlet NSLayoutConstraint* __weak _ruleEditorHeightConstraint;
}
#endif

- (IBAction)toggleUseAutoAssignRules:(id)sender;
- (IBAction)orderFrontRulesSheet:(id)sender;
- (IBAction)cancelRules:(id)sender;
- (IBAction)saveRules:(id)sender;

@end
