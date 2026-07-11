// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#import "InfoViewController.h"

@class LegacyStackView;
@class PiecesView;

@interface InfoActivityViewController : NSViewController<InfoViewController>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    BOOL _fSet;
    IBOutlet NSTextField* _fDateAddedField;
    IBOutlet NSTextField* _fDateCompletedField;
    IBOutlet NSTextField* _fDateActivityField;
    IBOutlet NSTextField* _fStateField;
    IBOutlet NSTextField* _fProgressField;
    IBOutlet NSTextField* _fHaveField;
    IBOutlet NSTextField* _fDownloadedTotalField;
    IBOutlet NSTextField* _fUploadedTotalField;
    IBOutlet NSTextField* _fFailedHashField;
    IBOutlet NSTextField* _fRatioField;
    IBOutlet NSTextField* _fDownloadTimeField;
    IBOutlet NSTextField* _fSeedTimeField;
    IBOutlet NSTextView* _fErrorMessageView;
    IBOutlet PiecesView* _fPiecesView;
    IBOutlet NSSegmentedControl* _fPiecesControl;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    IBOutlet LegacyStackView* _fActivityStackView;
#else
    IBOutlet NSStackView* _fActivityStackView;
#endif
    IBOutlet NSView* _fDatesView;
    CGFloat _fCurrentHeight;
    IBOutlet NSView* _fTransferView;
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

- (IBAction)setPiecesView:(id)sender;
- (IBAction)updatePiecesView:(id)sender;
- (void)clearView;

@property(nonatomic) IBOutlet NSView* fTransferView;
@property(nonatomic) CGFloat oldHeight;

@end
