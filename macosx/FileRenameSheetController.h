// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.
// Created by Mitchell Livingston on 1/20/13.

#import <AppKit/AppKit.h>

@class FileListNode;
@class Torrent;

@interface FileRenameSheetController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSTextField* __weak _labelField;
    IBOutlet NSTextField* __weak _inputField;
    IBOutlet NSButton* __weak _renameButton;
    IBOutlet NSButton* __weak _cancelButton;
    Torrent* _torrent;
    FileListNode* _node;
    NSString* _originalName;
}
#endif

+ (void)presentSheetForTorrent:(Torrent*)torrent
                modalForWindow:(NSWindow*)window
             completionHandler:(void (^)(BOOL didRename))completionHandler;
+ (void)presentSheetForFileListNode:(FileListNode*)node
                     modalForWindow:(NSWindow*)window
                  completionHandler:(void (^)(BOOL didRename))completionHandler;

- (IBAction)rename:(id)sender;
- (IBAction)cancelRename:(id)sender;

@end
