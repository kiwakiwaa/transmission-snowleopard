// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "AddWindowController.h"
#import "Controller.h"
#import "ExpandedPathToIconTransformer.h"
#import "FileOutlineController.h"
#import "GroupsController.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

static NSTimeInterval const kUpdateSeconds = 1.0;

typedef NS_ENUM(NSUInteger, PopupPriority) {
    PopupPriorityHigh = 0,
    PopupPriorityNormal = 1,
    PopupPriorityLow = 2,
};

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
static void TRPrepareLegacySettingsLabel(NSTextField* label)
{
    NSTextFieldCell* cell = (NSTextFieldCell*)label.cell;
    cell.usesSingleLineMode = YES;
    cell.lineBreakMode = NSLineBreakByTruncatingTail;
}

static CGFloat TRLegacySettingsLabelWidth(NSTextField* label, CGFloat minimumWidth, CGFloat maximumWidth)
{
    CGFloat const measuredWidth = ceil([label.cell cellSize].width);
    return MIN(MAX(measuredWidth, minimumWidth), maximumWidth);
}
#endif

@interface AddWindowController ()

@property(nonatomic) IBOutlet NSImageView* fIconView;
@property(nonatomic) IBOutlet NSImageView* fLocationImageView;
@property(nonatomic) IBOutlet NSTextField* fNameField;
@property(nonatomic) IBOutlet NSTextField* fStatusField;
@property(nonatomic) IBOutlet NSTextField* fLocationField;
@property(nonatomic) IBOutlet NSTextField* fDownloadLabel;
@property(nonatomic) IBOutlet NSTextField* fGroupLabel;
@property(nonatomic) IBOutlet NSTextField* fPriorityLabel;
@property(nonatomic) IBOutlet NSButton* fStartCheck;
@property(nonatomic) IBOutlet NSButton* fDeleteCheck;
@property(nonatomic) IBOutlet NSPopUpButton* fGroupPopUp;
@property(nonatomic) IBOutlet NSPopUpButton* fPriorityPopUp;
@property(nonatomic) IBOutlet NSProgressIndicator* fVerifyIndicator;

@property(nonatomic) IBOutlet NSTextField* fFileFilterField;
@property(nonatomic) IBOutlet NSButton* fCheckAllButton;
@property(nonatomic) IBOutlet NSButton* fUncheckAllButton;

@property(nonatomic) IBOutlet FileOutlineController* fFileController;
@property(nonatomic) IBOutlet NSScrollView* fFileScrollView;

@property(nonatomic, readonly) Controller* fController;

@property(nonatomic, copy) NSString* fDestination;
@property(nonatomic, readonly) NSString* fTorrentFile;
@property(nonatomic) BOOL fLockDestination;

@property(nonatomic, readonly) BOOL fDeleteTorrentEnableInitially;
@property(nonatomic, readonly) BOOL fCanToggleDelete;
@property(nonatomic) NSInteger fGroupValue;

@property(nonatomic, TR_OBJC_WEAK) NSTimer* fTimer;

@property(nonatomic) TorrentDeterminationType fGroupValueDetermination;

@end

@implementation AddWindowController

- (instancetype)initWithTorrent:(Torrent*)torrent
                          destination:(NSString*)path
                      lockDestination:(BOOL)lockDestination
                           controller:(Controller*)controller
                          torrentFile:(NSString*)torrentFile
    deleteTorrentCheckEnableInitially:(BOOL)deleteTorrent
                      canToggleDelete:(BOOL)canToggleDelete
{
    if ((self = [super initWithWindowNibName:@"AddWindow"]))
    {
        _torrent = torrent;
        _fDestination = path.stringByExpandingTildeInPath;
        _fLockDestination = lockDestination;

        _fController = controller;

        _fTorrentFile = torrentFile.stringByExpandingTildeInPath;

        _fDeleteTorrentEnableInitially = deleteTorrent;
        _fCanToggleDelete = canToggleDelete;

        _fGroupValue = torrent.groupValue;
        _fGroupValueDetermination = TorrentDeterminationAutomatic;

        _fVerifyIndicator.usesThreadedAnimation = YES;
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateCheckButtons:) name:@"TorrentFileCheckChange"
                                             object:self.torrent];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateGroupMenu:) name:@"UpdateGroups" object:nil];

    self.fFileController.torrent = self.torrent;

    NSString* name = self.torrent.name;
    self.window.title = name;
    self.fNameField.stringValue = name;
    self.fNameField.toolTip = name;

    //disable fullscreen support
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenNone;

    self.fIconView.image = self.torrent.icon;

    if (!self.torrent.folder)
    {
        self.fFileFilterField.hidden = YES;
        self.fCheckAllButton.hidden = YES;
        self.fUncheckAllButton.hidden = YES;

        NSRect scrollFrame = self.fFileScrollView.frame;
        CGFloat const diff = NSMinY(self.fFileScrollView.frame) - NSMinY(self.fFileFilterField.frame);
        scrollFrame.origin.y -= diff;
        scrollFrame.size.height += diff;
        self.fFileScrollView.frame = scrollFrame;
    }
    else
    {
        [self updateCheckButtons:nil];
    }

    [self setGroupsMenu];
    [self.fGroupPopUp selectItemWithTag:self.fGroupValue];

    PopupPriority priorityIndex;
    switch (self.torrent.priority)
    {
    case TR_PRI_HIGH:
        priorityIndex = PopupPriorityHigh;
        break;
    case TR_PRI_NORMAL:
        priorityIndex = PopupPriorityNormal;
        break;
    case TR_PRI_LOW:
        priorityIndex = PopupPriorityLow;
        break;
    default:
        NSAssert1(NO, @"Unknown priority for adding torrent: %d", self.torrent.priority);
        priorityIndex = PopupPriorityNormal;
    }
    [self.fPriorityPopUp selectItemAtIndex:priorityIndex];

    self.fStartCheck.state = [NSUserDefaults.standardUserDefaults boolForKey:@"AutoStartDownload"] ? NSControlStateValueOn :
                                                                                                     NSControlStateValueOff;

    self.fDeleteCheck.state = self.fDeleteTorrentEnableInitially ? NSControlStateValueOn : NSControlStateValueOff;
    self.fDeleteCheck.enabled = self.fCanToggleDelete;

    if (self.fDestination)
    {
        [self setDestinationPath:self.fDestination
               determinationType:(self.fLockDestination ? TorrentDeterminationUserSpecified : TorrentDeterminationAutomatic)];
    }
    else
    {
        self.fLocationField.stringValue = @"";
        self.fLocationImageView.image = nil;
    }

    self.fTimer = [NSTimer scheduledTimerWithTimeInterval:kUpdateSeconds target:self selector:@selector(updateFiles)
                                                 userInfo:nil
                                                  repeats:YES];
    [self updateFiles];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    self.window.delegate = (id<NSWindowDelegate>)self;
    [self layoutSettingsViewForLegacyAppKit];
#endif
}

- (void)windowDidLoad
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    [self layoutSettingsViewForLegacyAppKit];
#endif

    //if there is no destination, prompt for one right away
    if (!self.fDestination)
    {
        [self setDestination:nil];
    }
}

- (void)windowDidResize:(NSNotification*)notification
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    [self layoutSettingsViewForLegacyAppKit];
#endif
}

- (NSView*)legacySettingsSiblingWithClass:(Class)klass title:(NSString*)title action:(SEL)action
{
    NSView* contentView = self.fPriorityPopUp.superview;
    for (NSView* subview in contentView.subviews)
    {
        if (![subview isKindOfClass:klass])
        {
            continue;
        }

        if (title != nil && [subview respondsToSelector:@selector(stringValue)] && [[(id)subview stringValue] isEqualToString:title])
        {
            return subview;
        }

        if (action != NULL && [subview respondsToSelector:@selector(action)] && [(id)subview action] == action)
        {
            return subview;
        }
    }

    return nil;
}

- (void)layoutSettingsViewForLegacyAppKit
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    NSView* contentView = self.fPriorityPopUp.superview;
    if (contentView == nil)
    {
        return;
    }

    CGFloat const width = NSWidth(contentView.bounds);
    CGFloat const leftMargin = 12.0;
    CGFloat const rightMargin = 12.0;
    CGFloat const controlGap = 8.0;
    CGFloat const popupWidth = 112.0;
    CGFloat const popupX = width - rightMargin - popupWidth;

    NSTextField* downloadLabel = self.fDownloadLabel;
    NSTextField* groupLabel = self.fGroupLabel;
    NSTextField* priorityLabel = self.fPriorityLabel;
    NSButton* verifyButton = (NSButton*)[self legacySettingsSiblingWithClass:[NSButton class] title:nil
                                                                      action:@selector(verifyLocalData:)];
    NSButton* changeButton = (NSButton*)[self legacySettingsSiblingWithClass:[NSButton class] title:nil
                                                                      action:@selector(setDestination:)];
    NSView* locationBox = self.fLocationField.superview.superview;

    if (downloadLabel == nil || groupLabel == nil || priorityLabel == nil || verifyButton == nil || changeButton == nil || locationBox == nil)
    {
        return;
    }

    TRPrepareLegacySettingsLabel(downloadLabel);
    TRPrepareLegacySettingsLabel(groupLabel);
    TRPrepareLegacySettingsLabel(priorityLabel);

    CGFloat const downloadLabelWidth = TRLegacySettingsLabelWidth(downloadLabel, 84.0, 132.0);
    CGFloat const locationX = leftMargin + downloadLabelWidth + controlGap;

    downloadLabel.frame = NSMakeRect(leftMargin, 68.0, downloadLabelWidth, 16.0);
    changeButton.frame = NSMakeRect(width - rightMargin - 72.0, 66.0, 72.0, 22.0);
    locationBox.frame = NSMakeRect(locationX, 64.0, MAX(120.0, NSMinX(changeButton.frame) - controlGap - locationX), 24.0);
    self.fLocationImageView.frame = NSMakeRect(4.0, 4.0, 16.0, 16.0);
    self.fLocationField.frame = NSMakeRect(24.0, 5.0, MAX(40.0, NSWidth(locationBox.frame) - 42.0), 14.0);

    verifyButton.frame = NSMakeRect(leftMargin, 36.0, 132.0, 24.0);
    self.fVerifyIndicator.frame = NSMakeRect(leftMargin, 16.0, 132.0, 12.0);

    CGFloat const labelLeftLimit = NSMaxX(verifyButton.frame) + controlGap;
    CGFloat const availableLabelWidth = MAX(48.0, popupX - controlGap - labelLeftLimit);
    CGFloat const labelWidth = MIN(MAX(TRLegacySettingsLabelWidth(groupLabel, 66.0, 120.0),
                                       TRLegacySettingsLabelWidth(priorityLabel, 66.0, 120.0)),
                                  availableLabelWidth);
    CGFloat const labelX = popupX - controlGap - labelWidth;

    groupLabel.frame = NSMakeRect(labelX, 40.0, labelWidth, 16.0);
    self.fGroupPopUp.frame = NSMakeRect(popupX, 36.0, popupWidth, 24.0);
    priorityLabel.frame = NSMakeRect(labelX, 12.0, labelWidth, 16.0);
    self.fPriorityPopUp.frame = NSMakeRect(popupX, 8.0, popupWidth, 24.0);
#endif
}

- (void)dealloc
{
    [_fTimer invalidate];
}

- (void)setDestination:(id)sender
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];

    panel.prompt = NSLocalizedString(@"Select", "Open torrent -> prompt");
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;

    panel.message = [NSString stringWithFormat:NSLocalizedString(@"Select the download folder for \"%@\"", "Add -> select destination folder"),
                                               self.torrent.name];

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK)
        {
            self.fLockDestination = YES;
            [self setDestinationPath:[(NSURL*)[panel.URLs objectAtIndex:0] path] determinationType:TorrentDeterminationUserSpecified];
        }
        else
        {
            if (!self.fDestination)
            {
                [self performSelectorOnMainThread:@selector(cancelAdd:) withObject:nil waitUntilDone:NO];
            }
        }
    }];
}

- (void)add:(id)sender
{
    if ([self.fDestination.lastPathComponent isEqualToString:self.torrent.name] &&
        [NSUserDefaults.standardUserDefaults boolForKey:@"WarningFolderDataSameName"])
    {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"The destination directory and root data directory have the same name.", "Add torrent -> same name -> title");
        alert.informativeText = NSLocalizedString(
            @"If you are attempting to use already existing data,"
             " the root data directory should be inside the destination directory.",
            "Add torrent -> same name -> message");
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "Add torrent -> same name -> button")];
        [alert addButtonWithTitle:NSLocalizedString(@"Add", "Add torrent -> same name -> button")];
        alert.showsSuppressionButton = YES;

        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if (alert.suppressionButton.state == NSControlStateValueOn)
            {
                [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"WarningFolderDataSameName"];
            }

            if (returnCode == NSAlertSecondButtonReturn)
            {
                [self performSelectorOnMainThread:@selector(confirmAdd) withObject:nil waitUntilDone:NO];
            }
        }];
    }
    else
    {
        [self confirmAdd];
    }
}

- (void)cancelAdd:(id)sender
{
    [self.window performClose:sender];
}

//only called on cancel
- (BOOL)windowShouldClose:(id)window
{
    [self.fTimer invalidate];
    self.fTimer = nil;

    self.fFileController.torrent = nil; //avoid a crash when window tries to update

    [self.fController askOpenConfirmed:self add:NO];
    return YES;
}

- (void)setFileFilterText:(id)sender
{
    self.fFileController.filterText = [sender stringValue];
}

- (IBAction)checkAll:(id)sender
{
    [self.fFileController checkAll];
}

- (IBAction)uncheckAll:(id)sender
{
    [self.fFileController uncheckAll];
}

- (void)verifyLocalData:(id)sender
{
    [self.torrent resetCache];
    [self updateFiles];
}

- (void)changePriority:(id)sender
{
    tr_priority_t priority;
    switch ([sender indexOfSelectedItem])
    {
    case PopupPriorityHigh:
        priority = TR_PRI_HIGH;
        break;
    case PopupPriorityNormal:
        priority = TR_PRI_NORMAL;
        break;
    case PopupPriorityLow:
        priority = TR_PRI_LOW;
        break;
    default:
        NSAssert1(NO, @"Unknown priority tag for adding torrent: %ld", [sender tag]);
        priority = TR_PRI_NORMAL;
    }
    self.torrent.priority = priority;
}

- (void)updateCheckButtons:(NSNotification*)notification
{
    NSString* statusString = [NSString stringForFileSize:self.torrent.size];
    if (self.torrent.folder)
    {
        //check buttons
        //keep synced with identical code in InfoFileViewController.m
        NSControlStateValue const filesCheckState = [self.torrent
            checkForFiles:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.torrent.fileCount)]];
        self.fCheckAllButton.enabled = filesCheckState != NSControlStateValueOn; //if anything is unchecked
        self.fUncheckAllButton.enabled = !self.torrent.allDownloaded; //if there are any checked files that aren't finished

        //status field
        NSString* fileString;
        NSUInteger count = self.torrent.fileCount;
        if (count != 1)
        {
            fileString = [NSString localizedStringWithFormat:NSLocalizedString(@"%lu files", "Add torrent -> info"), count];
        }
        else
        {
            fileString = NSLocalizedString(@"1 file", "Add torrent -> info");
        }

        NSString* selectedString = [NSString stringWithFormat:NSLocalizedString(@"%@ selected", "Add torrent -> info"),
                                                              [NSString stringForFileSize:self.torrent.totalSizeSelected]];

        statusString = [NSString stringWithFormat:@"%@, %@ (%@)", fileString, statusString, selectedString];
    }

    self.fStatusField.stringValue = statusString;
}

- (void)updateGroupMenu:(NSNotification*)notification
{
    [self setGroupsMenu];
    if (![self.fGroupPopUp selectItemWithTag:self.fGroupValue])
    {
        self.fGroupValue = -1;
        self.fGroupValueDetermination = TorrentDeterminationAutomatic;
        [self.fGroupPopUp selectItemWithTag:self.fGroupValue];
    }
}

#pragma mark - Private

- (void)updateFiles
{
    [self.torrent update];

    [self.fFileController reloadVisibleRows];

    [self updateCheckButtons:nil]; //call in case button state changed by checking

    if (self.torrent.checking)
    {
        BOOL const waiting = self.torrent.checkingWaiting;
        self.fVerifyIndicator.indeterminate = waiting;
        if (waiting)
        {
            [self.fVerifyIndicator startAnimation:self];
        }
        else
        {
            self.fVerifyIndicator.doubleValue = self.torrent.checkingProgress;
        }
    }
    else
    {
        self.fVerifyIndicator.indeterminate = YES; //we want to hide when stopped, which only applies when indeterminate
        [self.fVerifyIndicator stopAnimation:self];
    }
}

- (void)confirmAdd
{
    [self.fTimer invalidate];
    self.fTimer = nil;
    [self.torrent setGroupValue:self.fGroupValue determinationType:self.fGroupValueDetermination];

    if (self.fTorrentFile && self.fCanToggleDelete && self.fDeleteCheck.state == NSControlStateValueOn)
    {
        [Torrent trashFile:self.fTorrentFile error:nil];
    }

    if (self.fStartCheck.state == NSControlStateValueOn)
    {
        [self.torrent startTransfer];
    }

    self.fFileController.torrent = nil; //avoid a crash when window tries to update

    [self close];
    [self.fController askOpenConfirmed:self add:YES];
}

- (void)setDestinationPath:(NSString*)destination determinationType:(TorrentDeterminationType)determinationType
{
    destination = destination.stringByExpandingTildeInPath;
    if (!self.fDestination || ![self.fDestination isEqualToString:destination])
    {
        self.fDestination = destination;

        [self.torrent changeDownloadFolderBeforeUsing:self.fDestination determinationType:determinationType];
    }

    self.fLocationField.stringValue = self.fDestination.stringByAbbreviatingWithTildeInPath;
    self.fLocationField.toolTip = self.fDestination;

    ExpandedPathToIconTransformer* iconTransformer = [[ExpandedPathToIconTransformer alloc] init];
    self.fLocationImageView.image = [iconTransformer transformedValue:self.fDestination];
}

- (void)setGroupsMenu
{
    NSMenu* groupMenu = [GroupsController.groups groupMenuWithTarget:self action:@selector(changeGroupValue:) isSmall:NO];
    self.fGroupPopUp.menu = groupMenu;
}

- (void)changeGroupValue:(id)sender
{
    NSInteger previousGroup = self.fGroupValue;
    self.fGroupValue = [sender tag];
    self.fGroupValueDetermination = TorrentDeterminationUserSpecified;

    if (!self.fLockDestination)
    {
        if ([GroupsController.groups usesCustomDownloadLocationForIndex:self.fGroupValue])
        {
            [self setDestinationPath:[GroupsController.groups customDownloadLocationForIndex:self.fGroupValue]
                   determinationType:TorrentDeterminationAutomatic];
        }
        else if ([self.fDestination isEqualToString:[GroupsController.groups customDownloadLocationForIndex:previousGroup]])
        {
            [self setDestinationPath:[NSUserDefaults.standardUserDefaults stringForKey:@"DownloadFolder"]
                   determinationType:TorrentDeterminationAutomatic];
        }
    }
}

@end
