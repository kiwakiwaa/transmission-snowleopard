// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#import "Torrent.h"
#endif

@class Controller;
@class FileOutlineController;
@class Torrent;

@interface AddWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    Torrent* _torrent;
    IBOutlet NSImageView* _fIconView;
    IBOutlet NSImageView* _fLocationImageView;
    IBOutlet NSTextField* _fNameField;
    IBOutlet NSTextField* _fStatusField;
    IBOutlet NSTextField* _fLocationField;
    IBOutlet NSTextField* _fDownloadLabel;
    IBOutlet NSTextField* _fGroupLabel;
    IBOutlet NSTextField* _fPriorityLabel;
    IBOutlet NSButton* _fStartCheck;
    IBOutlet NSButton* _fDeleteCheck;
    IBOutlet NSPopUpButton* _fGroupPopUp;
    IBOutlet NSPopUpButton* _fPriorityPopUp;
    IBOutlet NSProgressIndicator* _fVerifyIndicator;
    IBOutlet NSTextField* _fFileFilterField;
    IBOutlet NSButton* _fCheckAllButton;
    IBOutlet NSButton* _fUncheckAllButton;
    IBOutlet FileOutlineController* _fFileController;
    IBOutlet NSScrollView* _fFileScrollView;
    Controller* _fController;
    NSString* _fDestination;
    NSString* _fTorrentFile;
    BOOL _fLockDestination;
    BOOL _fDeleteTorrentEnableInitially;
    BOOL _fCanToggleDelete;
    NSInteger _fGroupValue;
    __weak NSTimer* _fTimer;
    TorrentDeterminationType _fGroupValueDetermination;
}
#endif

@property(nonatomic, readonly) Torrent* torrent;

// if canToggleDelete is NO, we will also not delete the file regardless of the delete check's state
// (this is so it can be disabled and checked for a downloaded torrent, where the file's already deleted)
- (instancetype)initWithTorrent:(Torrent*)torrent
                          destination:(NSString*)path
                      lockDestination:(BOOL)lockDestination
                           controller:(Controller*)controller
                          torrentFile:(NSString*)torrentFile
    deleteTorrentCheckEnableInitially:(BOOL)deleteTorrent
                      canToggleDelete:(BOOL)canToggleDelete;

- (IBAction)setDestination:(id)sender;

- (IBAction)add:(id)sender;
- (IBAction)cancelAdd:(id)sender;

- (IBAction)setFileFilterText:(id)sender;
- (IBAction)checkAll:(id)sender;
- (IBAction)uncheckAll:(id)sender;

- (IBAction)verifyLocalData:(id)sender;

- (IBAction)changePriority:(id)sender;

- (void)updateCheckButtons:(NSNotification*)notification;

- (void)updateGroupMenu:(NSNotification*)notification;

@end
