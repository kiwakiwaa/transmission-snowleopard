// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#import "InfoViewController.h"

@class LegacyStackView;

@interface InfoOptionsViewController : NSViewController<InfoViewController>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    BOOL _fSet;
    IBOutlet NSPopUpButton* _fPriorityPopUp;
    IBOutlet NSPopUpButton* _fRatioPopUp;
    IBOutlet NSPopUpButton* _fIdlePopUp;
    IBOutlet NSButton* _fUploadLimitCheck;
    IBOutlet NSButton* _fDownloadLimitCheck;
    IBOutlet NSButton* _fGlobalLimitCheck;
    IBOutlet NSButton* _fRemoveSeedingCompleteCheck;
    IBOutlet NSTextField* _fUploadLimitField;
    IBOutlet NSTextField* _fDownloadLimitField;
    IBOutlet NSTextField* _fRatioLimitField;
    IBOutlet NSTextField* _fIdleLimitField;
    IBOutlet NSTextField* _fUploadLimitLabel;
    IBOutlet NSTextField* _fDownloadLimitLabel;
    IBOutlet NSTextField* _fIdleLimitLabel;
    IBOutlet NSTextField* _fRatioLimitGlobalLabel;
    IBOutlet NSTextField* _fIdleLimitGlobalLabel;
    IBOutlet NSTextField* _fPeersConnectLabel;
    IBOutlet NSTextField* _fPeersConnectField;
    NSString* _fInitialString;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    IBOutlet LegacyStackView* _fOptionsStackView;
#else
    IBOutlet NSStackView* _fOptionsStackView;
#endif
    IBOutlet NSView* _fSeedingView;
    CGFloat _fCurrentHeight;
    IBOutlet NSView* _fPriorityView;
    CGFloat _oldHeight;
}
#endif

- (NSRect)viewRect;
- (CGFloat)contentHeightForWindowWidth:(CGFloat)width;
- (void)checkLayout;
- (void)checkWindowSize;
- (void)checkWindowSizeAnimated:(BOOL)animate;
- (void)updateWindowLayout;

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)updateInfo;
- (void)updateOptions;

- (IBAction)setUseSpeedLimit:(id)sender;
- (IBAction)setSpeedLimit:(id)sender;
- (IBAction)setUseGlobalSpeedLimit:(id)sender;

- (IBAction)setRatioSetting:(id)sender;
- (IBAction)setRatioLimit:(id)sender;

- (IBAction)setIdleSetting:(id)sender;
- (IBAction)setIdleLimit:(id)sender;

- (IBAction)setRemoveWhenSeedingCompletes:(id)sender;

- (IBAction)setPriority:(id)sender;

- (IBAction)setPeersConnectLimit:(id)sender;

@property(nonatomic) IBOutlet NSView* fPriorityView;
@property(nonatomic) CGFloat oldHeight;

@end
