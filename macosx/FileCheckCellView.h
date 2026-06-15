// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class FileListNode;

@interface FileCheckCellView : NSTableCellView

@property(nonatomic, TR_OBJC_WEAK) FileListNode* node;

@end
