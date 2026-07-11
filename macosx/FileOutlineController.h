// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#import <AppKit/AppKit.h>
#else
#import <Foundation/Foundation.h>
#endif

@class Torrent;
@class FileOutlineView;

@interface FileOutlineController : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSMutableArray* _fFileList;
    IBOutlet FileOutlineView* _fOutline;
    __weak NSUndoManager* _batchRenameUndoManager;
    Torrent* _torrent;
    NSString* _filterText;
}
#endif

@property(nonatomic, readonly) FileOutlineView* outlineView;
@property(nonatomic) Torrent* torrent;
@property(nonatomic) NSString* filterText;

- (void)reloadVisibleRows;

- (void)setCheck:(id)sender;
- (void)setOnlySelectedCheck:(id)sender;
- (void)checkAll;
- (void)uncheckAll;
- (void)setPriority:(id)sender;

- (IBAction)revealFile:(id)sender;

- (void)renameSelected:(id)sender;

@end
