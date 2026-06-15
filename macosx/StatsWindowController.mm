// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "StatsWindowController.h"
#import "Controller.h"
#import "LegacyFormatters.h"
#import "NSStringAdditions.h"

static NSTimeInterval const kUpdateSeconds = 1.0;

@interface StatsWindowController ()<NSWindowRestoration>

@property(nonatomic) IBOutlet NSTextField* fUploadedField;
@property(nonatomic) IBOutlet NSTextField* fUploadedAllField;
@property(nonatomic) IBOutlet NSTextField* fDownloadedField;
@property(nonatomic) IBOutlet NSTextField* fDownloadedAllField;
@property(nonatomic) IBOutlet NSTextField* fRatioField;
@property(nonatomic) IBOutlet NSTextField* fRatioAllField;
@property(nonatomic) IBOutlet NSTextField* fTimeField;
@property(nonatomic) IBOutlet NSTextField* fTimeAllField;
@property(nonatomic) IBOutlet NSTextField* fNumOpenedField;
@property(nonatomic) IBOutlet NSTextField* fUploadedLabelField;
@property(nonatomic) IBOutlet NSTextField* fDownloadedLabelField;
@property(nonatomic) IBOutlet NSTextField* fRatioLabelField;
@property(nonatomic) IBOutlet NSTextField* fTimeLabelField;
@property(nonatomic) IBOutlet NSTextField* fNumOpenedLabelField;
@property(nonatomic) IBOutlet NSButton* fResetButton;
@property(nonatomic) NSTimer* fTimer;

@end

@implementation StatsWindowController

StatsWindowController* fStatsWindowInstance = nil;
tr_session* fLib = NULL;

+ (StatsWindowController*)statsWindow
{
    if (!fStatsWindowInstance)
    {
        if ((fStatsWindowInstance = [[self alloc] init]))
        {
            fLib = ((Controller*)[NSApp delegate]).sessionHandle;
        }
    }
    return fStatsWindowInstance;
}

- (instancetype)init
{
    return [super initWithWindowNibName:@"StatsWindow"];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self updateStats];

    self.fTimer = [NSTimer scheduledTimerWithTimeInterval:kUpdateSeconds target:self selector:@selector(updateStats)
                                                 userInfo:nil
                                                  repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:self.fTimer forMode:NSModalPanelRunLoopMode];
    [NSRunLoop.currentRunLoop addTimer:self.fTimer forMode:NSEventTrackingRunLoopMode];

    self.window.restorationClass = [self class];

    self.window.title = NSLocalizedString(@"Statistics", "Stats window -> title");

    //disable fullscreen support
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenNone;

    //set label text
    self.fUploadedLabelField.stringValue = [NSLocalizedString(@"Uploaded", "Stats window -> label") stringByAppendingString:@":"];
    self.fDownloadedLabelField.stringValue = [NSLocalizedString(@"Downloaded", "Stats window -> label") stringByAppendingString:@":"];
    self.fRatioLabelField.stringValue = [NSLocalizedString(@"Ratio", "Stats window -> label") stringByAppendingString:@":"];
    self.fTimeLabelField.stringValue = [NSLocalizedString(@"Running Time", "Stats window -> label") stringByAppendingString:@":"];
    self.fNumOpenedLabelField.stringValue = [NSLocalizedString(@"Program Started", "Stats window -> label") stringByAppendingString:@":"];

    self.fResetButton.title = NSLocalizedString(@"Reset", "Stats window -> reset button");
}

- (void)windowWillClose:(id)sender
{
    [self.fTimer invalidate];
    self.fTimer = nil;
    fStatsWindowInstance = nil;
}

+ (void)restoreWindowWithIdentifier:(NSString*)identifier
                              state:(NSCoder*)state
                  completionHandler:(void (^)(NSWindow*, NSError*))completionHandler
{
    NSAssert1([identifier isEqualToString:@"StatsWindow"], @"Trying to restore unexpected identifier %@", identifier);

    completionHandler(StatsWindowController.statsWindow.window, nil);
}

- (void)resetStats:(id)sender
{
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"WarningResetStats"])
    {
        [self performResetStats];
        return;
    }

    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to reset usage statistics?", "Stats reset -> title");
    alert.informativeText = NSLocalizedString(
        @"This will clear the global statistics displayed by Transmission."
         " Individual transfer statistics will not be affected.",
        "Stats reset -> message");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:NSLocalizedString(@"Reset", "Stats reset -> button")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "Stats reset -> button")];
    alert.showsSuppressionButton = YES;

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (alert.suppressionButton.state == NSControlStateValueOn)
        {
            [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"WarningResetStats"];
        }

        if (returnCode == NSAlertFirstButtonReturn)
        {
            [self performResetStats];
        }
    }];
}

- (NSString*)windowFrameAutosaveName
{
    return @"StatsWindow";
}

#pragma mark - Private

- (void)updateStats
{
    auto const statsAll = tr_sessionGetCumulativeStats(fLib);
    auto const statsSession = tr_sessionGetStats(fLib);

    self.fUploadedField.stringValue = [NSString stringForFileSize:statsSession.uploadedBytes];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    NSByteCountFormatter* byteFormatter = [[NSByteCountFormatter alloc] init];
    byteFormatter.allowedUnits = NSByteCountFormatterUseBytes;
    self.fUploadedField.toolTip = [byteFormatter stringFromByteCount:statsSession.uploadedBytes];
#else
    self.fUploadedField.toolTip = [NSString stringWithFormat:@"%llu bytes", static_cast<unsigned long long>(statsSession.uploadedBytes)];
#endif
    self.fUploadedAllField.stringValue = [NSString
        stringWithFormat:NSLocalizedString(@"%@ total", "stats total"), [NSString stringForFileSize:statsAll.uploadedBytes]];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    self.fUploadedAllField.toolTip = [byteFormatter stringFromByteCount:statsAll.uploadedBytes];
#else
    self.fUploadedAllField.toolTip = [NSString stringWithFormat:@"%llu bytes", static_cast<unsigned long long>(statsAll.uploadedBytes)];
#endif

    self.fDownloadedField.stringValue = [NSString stringForFileSize:statsSession.downloadedBytes];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    self.fDownloadedField.toolTip = [byteFormatter stringFromByteCount:statsSession.downloadedBytes];
#else
    self.fDownloadedField.toolTip = [NSString stringWithFormat:@"%llu bytes", static_cast<unsigned long long>(statsSession.downloadedBytes)];
#endif
    self.fDownloadedAllField.stringValue = [NSString
        stringWithFormat:NSLocalizedString(@"%@ total", "stats total"), [NSString stringForFileSize:statsAll.downloadedBytes]];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    self.fDownloadedAllField.toolTip = [byteFormatter stringFromByteCount:statsAll.downloadedBytes];
#else
    self.fDownloadedAllField.toolTip = [NSString stringWithFormat:@"%llu bytes", static_cast<unsigned long long>(statsAll.downloadedBytes)];
#endif

    self.fRatioField.stringValue = [NSString stringForRatio:statsSession.ratio];

    NSString* totalRatioString = static_cast<int>(statsAll.ratio) != TR_RATIO_NA ?
        [NSString stringWithFormat:NSLocalizedString(@"%@ total", "stats total"), [NSString stringForRatio:statsAll.ratio]] :
        NSLocalizedString(@"Total N/A", "stats total");
    self.fRatioAllField.stringValue = totalRatioString;

    self.fTimeField.stringValue = TRStatsDurationString(statsSession.secondsActive);
    self.fTimeAllField.stringValue = [NSString
        stringWithFormat:NSLocalizedString(@"%@ total", "stats total"), TRStatsDurationString(statsAll.secondsActive)];

    if (statsAll.sessionCount == 1)
    {
        self.fNumOpenedField.stringValue = NSLocalizedString(@"1 time", "stats window -> times opened");
    }
    else
    {
        self.fNumOpenedField.stringValue = [NSString
            localizedStringWithFormat:NSLocalizedString(@"%llu times", "stats window -> times opened"), statsAll.sessionCount];
    }
}

- (void)performResetStats
{
    tr_sessionClearStats(fLib);
    [self updateStats];
}

@end
