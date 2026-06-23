// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface FileBatchRenameSheetController : NSWindowController

+ (void)presentSheetForFileListNodes:(NSArray*)nodes
                       modalForWindow:(NSWindow*)window
                    completionHandler:(void (^)(BOOL didRename, NSArray* operations))completionHandler;

- (IBAction)rename:(id)sender;
- (IBAction)cancelRename:(id)sender;

@end
