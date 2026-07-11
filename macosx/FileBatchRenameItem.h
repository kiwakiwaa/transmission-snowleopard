// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

@class FileListNode;

@interface FileBatchRenameItem : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    FileListNode* _node;
    NSString* _originalName;
    NSString* _originalPath;
    NSUInteger _visibleOrderIndex;
    BOOL _active;
    NSString* _generatedName;
    NSString* _validationMessage;
}
#endif

@property(nonatomic, readonly) FileListNode* node;
@property(nonatomic, copy, readonly) NSString* originalName;
@property(nonatomic, copy, readonly) NSString* originalPath;
@property(nonatomic, readonly) NSUInteger visibleOrderIndex;

@property(nonatomic) BOOL active;
@property(nonatomic, copy) NSString* generatedName;
@property(nonatomic, copy) NSString* validationMessage;

@property(nonatomic, readonly) BOOL valid;
@property(nonatomic, readonly) BOOL changed;
@property(nonatomic, readonly) BOOL visible;
@property(nonatomic, readonly) NSString* originalFullPath;

- (instancetype)initWithFileListNode:(FileListNode*)node visibleOrderIndex:(NSUInteger)visibleOrderIndex;

@end
