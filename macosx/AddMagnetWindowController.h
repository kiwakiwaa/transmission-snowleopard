// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class Controller;
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#import "Torrent.h"
#else
@class Torrent;
#endif

@interface AddMagnetWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    Torrent* _torrent;
    IBOutlet NSImageView* _fLocationImageView;
    IBOutlet NSTextField* _fNameField;
    IBOutlet NSTextField* _fLocationField;
    IBOutlet NSButton* _fStartCheck;
    IBOutlet NSPopUpButton* _fGroupPopUp;
    IBOutlet NSPopUpButton* _fPriorityPopUp;
    Controller* _fController;
    NSString* _fDestination;
    NSInteger _fGroupValue;
    TorrentDeterminationType _fGroupDeterminationType;
}
#endif

@property(nonatomic, readonly) Torrent* torrent;

- (instancetype)initWithTorrent:(Torrent*)torrent destination:(NSString*)path controller:(Controller*)controller;

- (IBAction)setDestination:(id)sender;

- (IBAction)add:(id)sender;
- (IBAction)cancelAdd:(id)sender;

- (IBAction)changePriority:(id)sender;

- (void)updateGroupMenu:(NSNotification*)notification;

@end
