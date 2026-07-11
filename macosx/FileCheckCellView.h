// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class FileListNode;

@interface FileCheckCellView : NSTableCellView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    __weak FileListNode* _node;
    __weak NSButton* _checkButton;
}
#endif

@property(nonatomic, weak) FileListNode* node;

@end
