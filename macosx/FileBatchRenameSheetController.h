// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class FileBatchRenameSession;

@interface FileBatchRenameSheetController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSTextField* __weak _ruleLabel;
    IBOutlet NSTextField* __weak _searchLabel;
    IBOutlet NSTextField* __weak _replacementLabel;
    IBOutlet NSTextField* __weak _textLabel;
    IBOutlet NSTextField* __weak _dateFormatLabel;
    IBOutlet NSTextField* __weak _dateLocationLabel;
    IBOutlet NSTextField* __weak _sequenceTextLabel;
    IBOutlet NSTextField* __weak _sequenceLocationLabel;
    IBOutlet NSTextField* __weak _sequenceDigitsLabel;
    IBOutlet NSTextField* __weak _sequenceStartLabel;
    IBOutlet NSTextField* __weak _characterModeLabel;
    IBOutlet NSTextField* __weak _characterLocationLabel;
    IBOutlet NSTextField* __weak _characterCountLabel;
    IBOutlet NSTextField* __weak _regexPatternLabel;
    IBOutlet NSTextField* __weak _regexReplacementLabel;
    IBOutlet NSPopUpButton* __weak _rulePopup;
    IBOutlet NSView* __weak _replaceRuleView;
    IBOutlet NSView* __weak _textRuleView;
    IBOutlet NSView* __weak _dateRuleView;
    IBOutlet NSView* __weak _sequenceRuleView;
    IBOutlet NSView* __weak _characterRemovalRuleView;
    IBOutlet NSView* __weak _regularExpressionRuleView;
    IBOutlet NSView* __weak _changeCaseRuleView;
    IBOutlet NSButton* __weak _renameButton;
    IBOutlet NSButton* __weak _cancelButton;
    FileBatchRenameSession* _session;
    void (^_completionHandler)(BOOL didRename, NSArray* operations);
    NSArray* _completedOperations;
    IBOutlet NSPopUpButton* __weak _replaceModePopup;
    IBOutlet NSPopUpButton* __weak _dateTextPlacementPopup;
    IBOutlet NSPopUpButton* __weak _sequenceTextPlacementPopup;
    IBOutlet NSPopUpButton* __weak _characterRemovalModePopup;
    IBOutlet NSTextField* __weak _searchField;
    IBOutlet NSTextField* __weak _replacementField;
    IBOutlet NSTextField* __weak _customTextField;
    IBOutlet NSTextField* __weak _sequenceTextField;
    IBOutlet NSTextField* __weak _regexPatternField;
    IBOutlet NSTextField* __weak _regexReplacementField;
    IBOutlet NSTextField* __weak _dateFormatField;
    IBOutlet NSTextField* __weak _sequenceStartField;
    IBOutlet NSTextField* __weak _sequenceDigitsField;
    IBOutlet NSTextField* __weak _characterLocationField;
    IBOutlet NSTextField* __weak _characterCountField;
    IBOutlet NSStepper* __weak _sequenceStartStepper;
    IBOutlet NSStepper* __weak _sequenceDigitsStepper;
    IBOutlet NSStepper* __weak _characterLocationStepper;
    IBOutlet NSStepper* __weak _characterCountStepper;
    IBOutlet NSSegmentedControl* __weak _caseSegmentedControl;
    IBOutlet NSScrollView* __weak _tableScrollView;
    IBOutlet NSTableView* __weak _tableView;
    IBOutlet NSTextField* __weak _statusField;
}
#endif

+ (void)presentSheetForFileListNodes:(NSArray*)nodes
                       modalForWindow:(NSWindow*)window
                    completionHandler:(void (^)(BOOL didRename, NSArray* operations))completionHandler;

- (IBAction)rename:(id)sender;
- (IBAction)cancelRename:(id)sender;

@end
