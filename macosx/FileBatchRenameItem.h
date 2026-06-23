// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

@class FileListNode;

@interface FileBatchRenameItem : NSObject

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
