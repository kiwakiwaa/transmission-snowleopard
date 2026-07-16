// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileBatchRenameSheetController.h"

#import "CocoaCompatibility.h"
#import "FileBatchRenameItem.h"
#import "FileBatchRenameSession.h"
#import "LegacyArchiving.h"
#import "RenameRules.h"

#include <libtransmission/macos-version.h>
static NSString* const kBatchRenameTableDragType = @"TransmissionBatchRenameTableDragType";

typedef NS_ENUM(NSInteger, BatchRenameRulePopupTag) {
    BatchRenameRulePopupTagReplace = 0,
    BatchRenameRulePopupTagAppend = 1,
    BatchRenameRulePopupTagPrepend = 2,
    BatchRenameRulePopupTagDate = 3,
    BatchRenameRulePopupTagSequence = 4,
    BatchRenameRulePopupTagCharacterRemoval = 5,
    BatchRenameRulePopupTagRegularExpression = 6,
    BatchRenameRulePopupTagChangeCase = 7,
};

@interface FileBatchRenameSheetController ()<NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSControlTextEditingDelegate>

@property(nonatomic, weak) IBOutlet NSTextField* ruleLabel;
@property(nonatomic, weak) IBOutlet NSTextField* searchLabel;
@property(nonatomic, weak) IBOutlet NSTextField* replacementLabel;
@property(nonatomic, weak) IBOutlet NSTextField* textLabel;
@property(nonatomic, weak) IBOutlet NSTextField* dateFormatLabel;
@property(nonatomic, weak) IBOutlet NSTextField* dateLocationLabel;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceTextLabel;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceLocationLabel;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceDigitsLabel;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceStartLabel;
@property(nonatomic, weak) IBOutlet NSTextField* characterModeLabel;
@property(nonatomic, weak) IBOutlet NSTextField* characterLocationLabel;
@property(nonatomic, weak) IBOutlet NSTextField* characterCountLabel;
@property(nonatomic, weak) IBOutlet NSTextField* regexPatternLabel;
@property(nonatomic, weak) IBOutlet NSTextField* regexReplacementLabel;

@property(nonatomic, weak) IBOutlet NSPopUpButton* rulePopup;
@property(nonatomic, weak) IBOutlet NSView* replaceRuleView;
@property(nonatomic, weak) IBOutlet NSView* textRuleView;
@property(nonatomic, weak) IBOutlet NSView* dateRuleView;
@property(nonatomic, weak) IBOutlet NSView* sequenceRuleView;
@property(nonatomic, weak) IBOutlet NSView* characterRemovalRuleView;
@property(nonatomic, weak) IBOutlet NSView* regularExpressionRuleView;
@property(nonatomic, weak) IBOutlet NSView* changeCaseRuleView;

@property(nonatomic, weak) IBOutlet NSButton* renameButton;
@property(nonatomic, weak) IBOutlet NSButton* cancelButton;

@property(nonatomic) FileBatchRenameSession* session;
@property(nonatomic, copy) void (^completionHandler)(BOOL didRename, NSArray* operations);
@property(nonatomic, copy) NSArray* completedOperations;

@property(nonatomic, weak) IBOutlet NSPopUpButton* replaceModePopup;
@property(nonatomic, weak) IBOutlet NSPopUpButton* dateTextPlacementPopup;
@property(nonatomic, weak) IBOutlet NSPopUpButton* sequenceTextPlacementPopup;
@property(nonatomic, weak) IBOutlet NSPopUpButton* characterRemovalModePopup;
@property(nonatomic, weak) IBOutlet NSTextField* searchField;
@property(nonatomic, weak) IBOutlet NSTextField* replacementField;
@property(nonatomic, weak) IBOutlet NSTextField* customTextField;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceTextField;
@property(nonatomic, weak) IBOutlet NSTextField* regexPatternField;
@property(nonatomic, weak) IBOutlet NSTextField* regexReplacementField;
@property(nonatomic, weak) IBOutlet NSTextField* dateFormatField;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceStartField;
@property(nonatomic, weak) IBOutlet NSTextField* sequenceDigitsField;
@property(nonatomic, weak) IBOutlet NSTextField* characterLocationField;
@property(nonatomic, weak) IBOutlet NSTextField* characterCountField;
@property(nonatomic, weak) IBOutlet NSStepper* sequenceStartStepper;
@property(nonatomic, weak) IBOutlet NSStepper* sequenceDigitsStepper;
@property(nonatomic, weak) IBOutlet NSStepper* characterLocationStepper;
@property(nonatomic, weak) IBOutlet NSStepper* characterCountStepper;
@property(nonatomic, weak) IBOutlet NSSegmentedControl* caseSegmentedControl;
@property(nonatomic, weak) IBOutlet NSScrollView* tableScrollView;
@property(nonatomic, weak) IBOutlet NSTableView* tableView;
@property(nonatomic, weak) IBOutlet NSTextField* statusField;

@end

@implementation FileBatchRenameSheetController

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize ruleLabel = _ruleLabel;
@synthesize searchLabel = _searchLabel;
@synthesize replacementLabel = _replacementLabel;
@synthesize textLabel = _textLabel;
@synthesize dateFormatLabel = _dateFormatLabel;
@synthesize dateLocationLabel = _dateLocationLabel;
@synthesize sequenceTextLabel = _sequenceTextLabel;
@synthesize sequenceLocationLabel = _sequenceLocationLabel;
@synthesize sequenceDigitsLabel = _sequenceDigitsLabel;
@synthesize sequenceStartLabel = _sequenceStartLabel;
@synthesize characterModeLabel = _characterModeLabel;
@synthesize characterLocationLabel = _characterLocationLabel;
@synthesize characterCountLabel = _characterCountLabel;
@synthesize regexPatternLabel = _regexPatternLabel;
@synthesize regexReplacementLabel = _regexReplacementLabel;
@synthesize rulePopup = _rulePopup;
@synthesize replaceRuleView = _replaceRuleView;
@synthesize textRuleView = _textRuleView;
@synthesize dateRuleView = _dateRuleView;
@synthesize sequenceRuleView = _sequenceRuleView;
@synthesize characterRemovalRuleView = _characterRemovalRuleView;
@synthesize regularExpressionRuleView = _regularExpressionRuleView;
@synthesize changeCaseRuleView = _changeCaseRuleView;
@synthesize renameButton = _renameButton;
@synthesize cancelButton = _cancelButton;
@synthesize session = _session;
@synthesize completionHandler = _completionHandler;
@synthesize completedOperations = _completedOperations;
@synthesize replaceModePopup = _replaceModePopup;
@synthesize dateTextPlacementPopup = _dateTextPlacementPopup;
@synthesize sequenceTextPlacementPopup = _sequenceTextPlacementPopup;
@synthesize characterRemovalModePopup = _characterRemovalModePopup;
@synthesize searchField = _searchField;
@synthesize replacementField = _replacementField;
@synthesize customTextField = _customTextField;
@synthesize sequenceTextField = _sequenceTextField;
@synthesize regexPatternField = _regexPatternField;
@synthesize regexReplacementField = _regexReplacementField;
@synthesize dateFormatField = _dateFormatField;
@synthesize sequenceStartField = _sequenceStartField;
@synthesize sequenceDigitsField = _sequenceDigitsField;
@synthesize characterLocationField = _characterLocationField;
@synthesize characterCountField = _characterCountField;
@synthesize sequenceStartStepper = _sequenceStartStepper;
@synthesize sequenceDigitsStepper = _sequenceDigitsStepper;
@synthesize characterLocationStepper = _characterLocationStepper;
@synthesize characterCountStepper = _characterCountStepper;
@synthesize caseSegmentedControl = _caseSegmentedControl;
@synthesize tableScrollView = _tableScrollView;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
#endif

- (void)endRenameSheetWithReturnCode:(NSModalResponse)returnCode
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    [NSApp endSheet:self.window returnCode:returnCode];
#else
    [self.window.sheetParent endSheet:self.window returnCode:returnCode];
#endif
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
- (void)prepareForTigerSheetControllerRelease
{
    self.tableView.delegate = nil;
    self.tableView.dataSource = nil;
    [self.tableView unregisterDraggedTypes];
    self.window.delegate = nil;
    [self close];
}
#endif

+ (void)presentSheetForFileListNodes:(NSArray*)nodes
                       modalForWindow:(NSWindow*)window
                    completionHandler:(void (^)(BOOL didRename, NSArray* operations))completionHandler
{
    NSParameterAssert(nodes.count > 1);
    NSParameterAssert(window != nil);

    FileBatchRenameSheetController* controller = [[FileBatchRenameSheetController alloc] initWithWindowNibName:@"FileBatchRenameSheetController"];
    controller.session = [[FileBatchRenameSession alloc] initWithFileListNodes:nodes];
    controller.completionHandler = completionHandler;

    __block FileBatchRenameSheetController* strongController = controller;
    [window beginSheet:controller.window completionHandler:^(NSModalResponse returnCode) {
        if (strongController.completionHandler != nil)
        {
            strongController.completionHandler(returnCode == NSModalResponseOK, strongController.completedOperations);
        }
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
        [strongController prepareForTigerSheetControllerRelease];
#endif
        strongController = nil;
    }];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    self.window.title = NSLocalizedString(@"Batch Rename", "Batch rename sheet title");
    self.window.minSize = NSMakeSize(620.0, 420.0);
    self.window.maxSize = NSMakeSize(9999.0, 9999.0);

    [self localizeControls];
    [self populatePopups];
    [self configureControls];
    [self applyDefaultControlValues];
    [self updateRuleControlVisibility];
    [self applyControlValuesToSession];
}

#pragma mark - UI setup

- (void)localizeControls
{
    self.ruleLabel.stringValue = NSLocalizedString(@"Rule:", "Batch rename sheet label");
    self.searchLabel.stringValue = NSLocalizedString(@"Search:", "Batch rename sheet label");
    self.replacementLabel.stringValue = NSLocalizedString(@"Replacement:", "Batch rename sheet label");
    self.textLabel.stringValue = NSLocalizedString(@"Text:", "Batch rename sheet label");
    self.dateFormatLabel.stringValue = NSLocalizedString(@"Format:", "Batch rename sheet label");
    self.dateLocationLabel.stringValue = NSLocalizedString(@"Location:", "Batch rename sheet label");
    self.sequenceTextLabel.stringValue = NSLocalizedString(@"Text:", "Batch rename sheet label");
    self.sequenceLocationLabel.stringValue = NSLocalizedString(@"Location:", "Batch rename sheet label");
    self.sequenceDigitsLabel.stringValue = NSLocalizedString(@"Digits:", "Batch rename sheet label");
    self.sequenceStartLabel.stringValue = NSLocalizedString(@"Start:", "Batch rename sheet label");
    self.characterModeLabel.stringValue = NSLocalizedString(@"Mode:", "Batch rename sheet label");
    self.characterLocationLabel.stringValue = NSLocalizedString(@"Position:", "Batch rename sheet label");
    self.characterCountLabel.stringValue = NSLocalizedString(@"Count:", "Batch rename sheet label");
    self.regexPatternLabel.stringValue = NSLocalizedString(@"Pattern:", "Batch rename sheet label");
    self.regexReplacementLabel.stringValue = NSLocalizedString(@"Replacement:", "Batch rename sheet label");

    self.ruleLabel.hidden = YES;
    self.searchLabel.hidden = YES;
    self.replacementLabel.hidden = YES;
    self.textLabel.hidden = YES;
    self.regexPatternLabel.hidden = YES;
    self.regexReplacementLabel.hidden = YES;

    ((NSTextFieldCell*)self.searchField.cell).placeholderString = NSLocalizedString(
        @"Original Text", "Batch rename text field placeholder");
    ((NSTextFieldCell*)self.replacementField.cell).placeholderString = NSLocalizedString(
        @"New Text", "Batch rename text field placeholder");
    ((NSTextFieldCell*)self.customTextField.cell).placeholderString = NSLocalizedString(@"Text", "Batch rename text field placeholder");
    ((NSTextFieldCell*)self.regexPatternField.cell).placeholderString = NSLocalizedString(
        @"Original Text", "Batch rename text field placeholder");
    ((NSTextFieldCell*)self.regexReplacementField.cell).placeholderString = NSLocalizedString(
        @"New Text", "Batch rename text field placeholder");

    self.renameButton.title = NSLocalizedString(@"Rename", "rename sheet button");
    self.cancelButton.title = NSLocalizedString(@"Cancel", "rename sheet button");

    [[[self tableColumnWithIdentifier:@"Original"] headerCell] setStringValue:NSLocalizedString(
                                                                  @"Original Filename",
                                                                  "Batch rename table header")];
    [[[self tableColumnWithIdentifier:@"Renamed"] headerCell] setStringValue:NSLocalizedString(
                                                                 @"Renamed Filename",
                                                                 "Batch rename table header")];
}

- (void)populatePopups
{
    [self resetPopup:self.rulePopup];
    [self addItemWithTitle:NSLocalizedString(@"Replace", "Batch rename rule") tag:BatchRenameRulePopupTagReplace toPopup:self.rulePopup];
    [self addItemWithTitle:NSLocalizedString(@"Append", "Batch rename rule") tag:BatchRenameRulePopupTagAppend toPopup:self.rulePopup];
    [self addItemWithTitle:NSLocalizedString(@"Prepend", "Batch rename rule") tag:BatchRenameRulePopupTagPrepend toPopup:self.rulePopup];
    [self addItemWithTitle:NSLocalizedString(@"Date", "Batch rename rule") tag:BatchRenameRulePopupTagDate toPopup:self.rulePopup];
    [self addItemWithTitle:NSLocalizedString(@"Sequence", "Batch rename rule") tag:BatchRenameRulePopupTagSequence toPopup:self.rulePopup];
    [self addItemWithTitle:NSLocalizedString(@"Character Removal", "Batch rename rule") tag:BatchRenameRulePopupTagCharacterRemoval toPopup:self.rulePopup];
    if ([RenameRules regularExpressionRuleAvailable])
    {
        [self addItemWithTitle:NSLocalizedString(@"Regular Expression", "Batch rename rule")
                           tag:BatchRenameRulePopupTagRegularExpression
                       toPopup:self.rulePopup];
    }
    [self addItemWithTitle:NSLocalizedString(@"Change Case", "Batch rename rule") tag:BatchRenameRulePopupTagChangeCase toPopup:self.rulePopup];

    [self resetPopup:self.replaceModePopup];
    [self addItemWithTitle:NSLocalizedString(@"First", "Batch rename replace mode") tag:RenameRuleReplaceModeFirst toPopup:self.replaceModePopup];
    [self addItemWithTitle:NSLocalizedString(@"Last", "Batch rename replace mode") tag:RenameRuleReplaceModeLast toPopup:self.replaceModePopup];
    [self addItemWithTitle:NSLocalizedString(@"All", "Batch rename replace mode") tag:RenameRuleReplaceModeAll toPopup:self.replaceModePopup];

    [self populateTextPlacementPopup:self.dateTextPlacementPopup];
    [self populateTextPlacementPopup:self.sequenceTextPlacementPopup];

    [self resetPopup:self.characterRemovalModePopup];
    [self addItemWithTitle:NSLocalizedString(@"From Start", "Batch rename character removal mode")
                       tag:RenameRuleCharacterRemovalModeFromStart
                   toPopup:self.characterRemovalModePopup];
    [self addItemWithTitle:NSLocalizedString(@"From End", "Batch rename character removal mode")
                       tag:RenameRuleCharacterRemovalModeFromEnd
                   toPopup:self.characterRemovalModePopup];
    [self addItemWithTitle:NSLocalizedString(@"Range", "Batch rename character removal mode")
                       tag:RenameRuleCharacterRemovalModeRange
                   toPopup:self.characterRemovalModePopup];

    [self.caseSegmentedControl setSegmentCount:3];
    [self.caseSegmentedControl setLabel:NSLocalizedString(@"Title Case", "Batch rename case mode") forSegment:0];
    [self.caseSegmentedControl setLabel:NSLocalizedString(@"lowercase", "Batch rename case mode") forSegment:1];
    [self.caseSegmentedControl setLabel:NSLocalizedString(@"UPPERCASE", "Batch rename case mode") forSegment:2];
}

- (void)populateTextPlacementPopup:(NSPopUpButton*)popup
{
    [self resetPopup:popup];
    [self addItemWithTitle:NSLocalizedString(@"Replace", "Batch rename placement") tag:RenameRuleTextPlacementReplace toPopup:popup];
    [self addItemWithTitle:NSLocalizedString(@"Append", "Batch rename placement") tag:RenameRuleTextPlacementAppend toPopup:popup];
    [self addItemWithTitle:NSLocalizedString(@"Prepend", "Batch rename placement") tag:RenameRuleTextPlacementPrepend toPopup:popup];
}

- (void)resetPopup:(NSPopUpButton*)popup
{
    if (popup.menu == nil)
    {
        popup.menu = [[NSMenu alloc] initWithTitle:@""];
    }
    [popup removeAllItems];
}

- (void)configureControls
{
    self.rulePopup.target = self;
    self.rulePopup.action = @selector(ruleChanged:);
    self.replaceModePopup.target = self;
    self.replaceModePopup.action = @selector(controlValueChanged:);
    self.dateTextPlacementPopup.target = self;
    self.dateTextPlacementPopup.action = @selector(controlValueChanged:);
    self.sequenceTextPlacementPopup.target = self;
    self.sequenceTextPlacementPopup.action = @selector(controlValueChanged:);
    self.characterRemovalModePopup.target = self;
    self.characterRemovalModePopup.action = @selector(controlValueChanged:);
    self.caseSegmentedControl.target = self;
    self.caseSegmentedControl.action = @selector(controlValueChanged:);
    self.renameButton.target = self;
    self.renameButton.action = @selector(rename:);
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelRename:);

    NSArray* popups = @[
        self.rulePopup,
        self.replaceModePopup,
        self.dateTextPlacementPopup,
        self.sequenceTextPlacementPopup,
        self.characterRemovalModePopup
    ];
    for (NSPopUpButton* popup in popups)
    {
        [self configurePopupAppearance:popup];
    }

    NSArray* textFields = @[
        self.searchField,
        self.replacementField,
        self.customTextField,
        self.sequenceTextField,
        self.regexPatternField,
        self.regexReplacementField,
        self.dateFormatField,
        self.sequenceStartField,
        self.sequenceDigitsField,
        self.characterLocationField,
        self.characterCountField
    ];
    for (NSTextField* field in textFields)
    {
        field.delegate = self;
    }

    [self configureStepper:self.sequenceStartStepper value:1 min:0 max:999999];
    [self configureStepper:self.sequenceDigitsStepper value:2 min:1 max:9];
    [self configureStepper:self.characterLocationStepper value:1 min:1 max:999999];
    [self configureStepper:self.characterCountStepper value:1 min:1 max:999999];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    [self.tableView registerForDraggedTypes:@[ kBatchRenameTableDragType ]];

    [self configurePreviewTableAppearance];
    [self configureTableColumnCells];
}

- (void)configurePreviewTableAppearance
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9 && TR_MACOS_DEPLOYMENT_BEFORE_10_10
    NSTableHeaderView* headerView = [[NSTableHeaderView alloc] initWithFrame:self.tableView.headerView.frame];
    headerView.autoresizingMask = self.tableView.headerView.autoresizingMask;
    self.tableView.headerView = headerView;

    NSRect headerFrame = self.tableView.headerView.frame;
    headerFrame.size.height = self.tableView.rowHeight + self.tableView.intercellSpacing.height;
    self.tableView.headerView.frame = headerFrame;
#endif

    self.tableScrollView.autohidesScrollers = YES;
    self.tableScrollView.drawsBackground = YES;
    self.tableScrollView.backgroundColor = NSColor.controlColor;
    self.tableScrollView.contentView.drawsBackground = YES;
    self.tableScrollView.contentView.backgroundColor = NSColor.controlColor;

    self.tableView.backgroundColor = NSColor.controlBackgroundColor;

    NSView* headerClipView = self.tableView.headerView.superview;
    if ([headerClipView isKindOfClass:[NSClipView class]])
    {
        NSClipView* clipView = (NSClipView*)headerClipView;
        clipView.drawsBackground = YES;
        clipView.backgroundColor = NSColor.controlColor;
    }
}

- (void)configureStepper:(NSStepper*)stepper value:(NSInteger)value min:(NSInteger)min max:(NSInteger)max
{
    stepper.minValue = min;
    stepper.maxValue = max;
    stepper.integerValue = value;
    stepper.target = self;
    stepper.action = @selector(stepperChanged:);
}

- (void)configurePopupAppearance:(NSPopUpButton*)popup
{
    [popup setBordered:YES];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [popup setBezelStyle:NSRoundedBezelStyle];
#pragma clang diagnostic pop
    [popup setShowsBorderOnlyWhileMouseInside:NO];
    [popup setPullsDown:NO];
    [(NSPopUpButtonCell*)popup.cell setArrowPosition:NSPopUpArrowAtCenter];
    [(NSPopUpButtonCell*)popup.cell setUsesItemFromMenu:YES];
    [(NSPopUpButtonCell*)popup.cell setAltersStateOfSelectedItem:YES];
    [popup setNeedsDisplay:YES];
}

- (void)configureTableColumnCells
{
    NSTableColumn* activeColumn = [self tableColumnWithIdentifier:@"Active"];
    activeColumn.editable = YES;

    NSTableColumn* originalColumn = [self tableColumnWithIdentifier:@"Original"];
    NSTableColumn* renamedColumn = [self tableColumnWithIdentifier:@"Renamed"];

    if ([originalColumn.dataCell respondsToSelector:@selector(setLineBreakMode:)])
    {
        [originalColumn.dataCell setLineBreakMode:NSLineBreakByTruncatingMiddle];
    }

    if ([renamedColumn.dataCell respondsToSelector:@selector(setLineBreakMode:)])
    {
        [renamedColumn.dataCell setLineBreakMode:NSLineBreakByTruncatingMiddle];
    }
}

- (NSTableColumn*)tableColumnWithIdentifier:(NSString*)identifier
{
    return [self.tableView tableColumnWithIdentifier:identifier];
}

- (void)addItemWithTitle:(NSString*)title tag:(NSInteger)tag toPopup:(NSPopUpButton*)popup
{
    [popup addItemWithTitle:title];
    [[popup itemAtIndex:popup.numberOfItems - 1] setTag:tag];
}

- (void)selectPopup:(NSPopUpButton*)popup tag:(NSInteger)tag
{
    for (NSMenuItem* item in [popup itemArray])
    {
        if (item.tag == tag)
        {
            [popup selectItem:item];
            return;
        }
    }
}

- (void)applyDefaultControlValues
{
    RenameRuleConfig* config = self.session.config;
    self.searchField.stringValue = config.searchText ?: @"";
    self.replacementField.stringValue = config.replacementText ?: @"";
    self.customTextField.stringValue = config.customText ?: @"";
    self.sequenceTextField.stringValue = config.customText ?: @"";
    self.regexPatternField.stringValue = config.regexPattern ?: @"";
    self.regexReplacementField.stringValue = config.regexReplacementText ?: @"";
    self.dateFormatField.stringValue = config.dateFormat ?: @"";
    self.sequenceStartField.integerValue = config.sequenceStart;
    self.sequenceDigitsField.integerValue = config.sequenceDigits;
    self.characterLocationField.integerValue = config.characterLocation;
    self.characterCountField.integerValue = config.characterCount;
    self.sequenceStartStepper.integerValue = config.sequenceStart;
    self.sequenceDigitsStepper.integerValue = config.sequenceDigits;
    self.characterLocationStepper.integerValue = config.characterLocation;
    self.characterCountStepper.integerValue = config.characterCount;
    self.caseSegmentedControl.selectedSegment = config.caseMode;

    [self selectPopup:self.rulePopup tag:BatchRenameRulePopupTagReplace];
    [self selectPopup:self.replaceModePopup tag:config.replaceMode];
    [self selectPopup:self.dateTextPlacementPopup tag:config.textPlacement];
    [self selectPopup:self.sequenceTextPlacementPopup tag:config.textPlacement];
    [self selectPopup:self.characterRemovalModePopup tag:config.characterRemovalMode];
}

#pragma mark - UI updates

- (IBAction)ruleChanged:(id)sender
{
    [self updateRuleControlVisibility];
    [self applyControlValuesToSession];
}

- (IBAction)controlValueChanged:(id)sender
{
    [self applyControlValuesToSession];
}

- (IBAction)stepperChanged:(id)sender
{
    if (sender == self.sequenceStartStepper)
    {
        self.sequenceStartField.integerValue = self.sequenceStartStepper.integerValue;
    }
    else if (sender == self.sequenceDigitsStepper)
    {
        self.sequenceDigitsField.integerValue = self.sequenceDigitsStepper.integerValue;
    }
    else if (sender == self.characterLocationStepper)
    {
        self.characterLocationField.integerValue = self.characterLocationStepper.integerValue;
    }
    else if (sender == self.characterCountStepper)
    {
        self.characterCountField.integerValue = self.characterCountStepper.integerValue;
    }

    [self applyControlValuesToSession];
}

- (void)controlTextDidChange:(NSNotification*)notification
{
    self.sequenceStartStepper.integerValue = self.sequenceStartField.integerValue;
    self.sequenceDigitsStepper.integerValue = self.sequenceDigitsField.integerValue;
    self.characterLocationStepper.integerValue = self.characterLocationField.integerValue;
    self.characterCountStepper.integerValue = self.characterCountField.integerValue;
    [self applyControlValuesToSession];
}

- (void)applyControlValuesToSession
{
    NSInteger const selectedRuleTag = [self.rulePopup.selectedItem tag];
    RenameRuleConfig* config = self.session.config;
    config.searchText = self.searchField.stringValue ?: @"";
    config.replacementText = self.replacementField.stringValue ?: @"";
    config.customText = selectedRuleTag == BatchRenameRulePopupTagSequence ? (self.sequenceTextField.stringValue ?: @"") :
        (self.customTextField.stringValue ?: @"");
    config.regexPattern = self.regexPatternField.stringValue ?: @"";
    config.regexReplacementText = self.regexReplacementField.stringValue ?: @"";
    config.dateFormat = self.dateFormatField.stringValue ?: @"";
    if (self.replaceModePopup.selectedItem != nil)
    {
        config.replaceMode = (RenameRuleReplaceMode)[self.replaceModePopup.selectedItem tag];
    }
    NSPopUpButton* textPlacementPopup = [self textPlacementPopupForRuleTag:selectedRuleTag];
    if (textPlacementPopup.selectedItem != nil)
    {
        config.textPlacement = (RenameRuleTextPlacement)[textPlacementPopup.selectedItem tag];
    }
    if (self.characterRemovalModePopup.selectedItem != nil)
    {
        config.characterRemovalMode = (RenameRuleCharacterRemovalMode)[self.characterRemovalModePopup.selectedItem tag];
    }
    config.characterLocation = MAX(1, self.characterLocationField.integerValue);
    config.characterCount = MAX(1, self.characterCountField.integerValue);
    config.sequenceStart = self.sequenceStartField.integerValue;
    config.sequenceDigits = MAX(1, self.sequenceDigitsField.integerValue);
    config.caseMode = (RenameRuleCaseMode)MAX(0, self.caseSegmentedControl.selectedSegment);

    switch (selectedRuleTag)
    {
    case BatchRenameRulePopupTagReplace:
        self.session.rule = [RenameRules replaceRuleForMode:config.replaceMode];
        break;

    case BatchRenameRulePopupTagAppend:
        self.session.rule = [RenameRules appendRule];
        break;

    case BatchRenameRulePopupTagPrepend:
        self.session.rule = [RenameRules prependRule];
        break;

    case BatchRenameRulePopupTagDate:
        self.session.rule = [RenameRules dateRule];
        break;

    case BatchRenameRulePopupTagSequence:
        self.session.rule = [RenameRules sequenceRule];
        break;

    case BatchRenameRulePopupTagCharacterRemoval:
        self.session.rule = [RenameRules characterRemovalRule];
        break;

    case BatchRenameRulePopupTagRegularExpression:
        self.session.rule = [RenameRules regularExpressionRule];
        break;

    case BatchRenameRulePopupTagChangeCase:
        self.session.rule = [RenameRules changeCaseRule];
        break;
    }

    [self.tableView reloadData];
    [self updateStatus];
}

- (void)updateRuleControlVisibility
{
    NSInteger const tag = [self.rulePopup.selectedItem tag];
    NSView* visibleRuleView = nil;

    [self hideAllRuleViews];

    switch (tag)
    {
    case BatchRenameRulePopupTagReplace:
        self.replaceRuleView.hidden = NO;
        visibleRuleView = self.replaceRuleView;
        break;

    case BatchRenameRulePopupTagAppend:
    case BatchRenameRulePopupTagPrepend:
        self.textRuleView.hidden = NO;
        visibleRuleView = self.textRuleView;
        break;

    case BatchRenameRulePopupTagDate:
        self.dateRuleView.hidden = NO;
        visibleRuleView = self.dateRuleView;
        break;

    case BatchRenameRulePopupTagSequence:
        self.sequenceRuleView.hidden = NO;
        visibleRuleView = self.sequenceRuleView;
        break;

    case BatchRenameRulePopupTagCharacterRemoval:
        self.characterRemovalRuleView.hidden = NO;
        visibleRuleView = self.characterRemovalRuleView;
        break;

    case BatchRenameRulePopupTagRegularExpression:
        self.regularExpressionRuleView.hidden = NO;
        visibleRuleView = self.regularExpressionRuleView;
        break;

    case BatchRenameRulePopupTagChangeCase:
        self.changeCaseRuleView.hidden = NO;
        visibleRuleView = self.changeCaseRuleView;
        break;
    }

    [self updatePreviewTableLayoutForRuleView:visibleRuleView];
}

- (void)hideAllRuleViews
{
    self.replaceRuleView.hidden = YES;
    self.textRuleView.hidden = YES;
    self.dateRuleView.hidden = YES;
    self.sequenceRuleView.hidden = YES;
    self.characterRemovalRuleView.hidden = YES;
    self.regularExpressionRuleView.hidden = YES;
    self.changeCaseRuleView.hidden = YES;
}

- (void)updatePreviewTableLayoutForRuleView:(NSView*)ruleView
{
    if (ruleView == nil || self.tableScrollView == nil || self.window.contentView == nil)
    {
        return;
    }

    NSRect const controlFrame = [ruleView.superview convertRect:ruleView.frame toView:self.window.contentView];
    NSRect tableFrame = self.tableScrollView.frame;
    CGFloat const tableBottom = NSMinY(tableFrame);
    CGFloat const desiredTableTop = MAX(tableBottom, NSMinY(controlFrame) - 22.0);

    tableFrame.size.height = MAX(120.0, desiredTableTop - tableBottom);
    self.tableScrollView.frame = tableFrame;
}

- (NSPopUpButton*)textPlacementPopupForRuleTag:(NSInteger)tag
{
    if (tag == BatchRenameRulePopupTagDate)
    {
        return self.dateTextPlacementPopup;
    }
    if (tag == BatchRenameRulePopupTagSequence)
    {
        return self.sequenceTextPlacementPopup;
    }
    return nil;
}

- (void)updateStatus
{
    self.renameButton.enabled = self.session.canRename;

    if (self.session.validationSummary.length > 0)
    {
        self.statusField.stringValue = self.session.validationSummary;
        self.statusField.textColor = NSColor.redColor;
        return;
    }

    NSUInteger count = 0;
    for (FileBatchRenameItem* item in self.session.items)
    {
        if (item.active && item.valid && item.changed)
        {
            count++;
        }
    }

    self.statusField.textColor = NSColor.controlTextColor;
    self.statusField.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%lu rows ready to rename.", "Batch rename validation status"),
                                                              (unsigned long)count];
}

#pragma mark - Actions

- (IBAction)rename:(id)sender
{
    self.renameButton.enabled = NO;
    self.statusField.textColor = NSColor.controlTextColor;
    self.statusField.stringValue = NSLocalizedString(@"Renaming...", "Batch rename validation status");

    [self.session executeWithCompletionHandler:^(BOOL success, NSString* errorMessage, NSArray* operations) {
        if (success)
        {
            self.completedOperations = operations;
            [self endRenameSheetWithReturnCode:NSModalResponseOK];
        }
        else
        {
            self.statusField.textColor = NSColor.redColor;
            self.statusField.stringValue = errorMessage ?: NSLocalizedString(@"Batch rename failed.", "Batch rename alert title");
            [self updateStatus];
            NSBeep();
        }
    }];
}

- (IBAction)cancelRename:(id)sender
{
    [self endRenameSheetWithReturnCode:NSModalResponseCancel];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView
{
    return self.session.displayedItems.count;
}

- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row
{
    FileBatchRenameItem* item = [self.session.displayedItems objectAtIndex:row];
    NSString* identifier = tableColumn.identifier;

    if ([identifier isEqualToString:@"Active"])
    {
        return @(item.active);
    }
    if ([identifier isEqualToString:@"Original"])
    {
        return item.originalName;
    }
    if ([identifier isEqualToString:@"Renamed"])
    {
        return item.active && item.changed ? item.generatedName : @"";
    }

    return @"";
}

- (void)tableView:(NSTableView*)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row
{
    if ([tableColumn.identifier isEqualToString:@"Active"])
    {
        [self.session setActive:[object boolValue] forDisplayedItemAtIndex:row];
        [self.tableView reloadData];
        [self updateStatus];
    }
}

- (BOOL)tableView:(NSTableView*)tableView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard*)pasteboard
{
    if (rowIndexes.count != 1)
    {
        return NO;
    }

    [pasteboard declareTypes:@[ kBatchRenameTableDragType ] owner:self];
    [pasteboard setData:TRArchivedDataForObject(rowIndexes) forType:kBatchRenameTableDragType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    if ([info.draggingPasteboard.types containsObject:kBatchRenameTableDragType])
    {
        [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
        return NSDragOperationGeneric;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)newRow
    dropOperation:(NSTableViewDropOperation)operation
{
    NSData* data = [info.draggingPasteboard dataForType:kBatchRenameTableDragType];
    NSIndexSet* indexes = TRUnarchiveObjectFromData(data, [NSSet setWithObject:NSIndexSet.class]);
    if (indexes.firstIndex == NSNotFound)
    {
        return NO;
    }

    NSInteger oldRow = indexes.firstIndex;
    if (oldRow < newRow)
    {
        newRow--;
    }

    NSUInteger targetRow = newRow < 0 ? 0 : MIN((NSUInteger)newRow, self.session.displayedItems.count);
    [self.session moveDisplayedItemAtIndex:oldRow toIndex:targetRow];
    [self.tableView reloadData];
    [self updateStatus];
    return YES;
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row
{
    FileBatchRenameItem* item = [self.session.displayedItems objectAtIndex:row];
    if (![cell respondsToSelector:@selector(setTextColor:)])
    {
        return;
    }

    if (item.validationMessage.length > 0 && ![tableColumn.identifier isEqualToString:@"Active"])
    {
        [cell setTextColor:NSColor.redColor];
    }
    else if (!item.active && [tableColumn.identifier isEqualToString:@"Original"])
    {
        [cell setTextColor:NSColor.disabledControlTextColor];
    }
    else
    {
        [cell setTextColor:NSColor.controlTextColor];
    }
}

@end
