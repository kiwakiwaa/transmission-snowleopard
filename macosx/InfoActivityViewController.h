// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "InfoViewController.h"

@interface InfoActivityViewController : NSViewController<InfoViewController>

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
