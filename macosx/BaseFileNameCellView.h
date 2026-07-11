// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class FileListNode;

@interface BaseFileNameCellView : NSTableCellView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    __weak FileListNode* _node;
    __weak NSImageView* _iconView;
    __weak NSTextField* _nameField;
    __weak NSTextField* _statusField;
}
#endif

@property(nonatomic, weak) FileListNode* node;

@end

@interface FileNameCellView : BaseFileNameCellView
@end

@interface FolderNameCellView : BaseFileNameCellView
@end
