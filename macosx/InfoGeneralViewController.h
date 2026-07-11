// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "InfoViewController.h"

@class Torrent;

@interface InfoGeneralViewController : NSViewController<InfoViewController>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* _fTorrents;
    BOOL _fSet;
    IBOutlet NSTextField* _fPiecesField;
    IBOutlet NSTextField* _fHashField;
    IBOutlet NSTextField* _fSecureField;
    IBOutlet NSTextField* _fDataLocationField;
    IBOutlet NSTextField* _fLastDataLocationField;
    IBOutlet NSTextField* _fLastDataLabel;
    IBOutlet NSTextField* _fCreatorField;
    IBOutlet NSTextField* _fDateCreatedField;
    IBOutlet NSTextView* _fCommentView;
    IBOutlet NSButton* _fRevealDataButton;
}
#endif

- (void)setInfoForTorrents:(NSArray*)torrents;
- (void)updateInfo;

- (IBAction)revealDataFile:(id)sender;

@end
