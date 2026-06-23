// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#import "RenameRule.h"

@class FileBatchRenameItem;
@class FileListNode;

typedef void (^FileBatchRenameCompletionHandler)(BOOL success, NSString* errorMessage);

@interface FileBatchRenameSession : NSObject

@property(nonatomic, readonly) NSArray* items;
@property(nonatomic, readonly) NSArray* displayedItems;
@property(nonatomic) id<RenameRule> rule;
@property(nonatomic) RenameRuleConfig* config;
@property(nonatomic, readonly) BOOL canRename;
@property(nonatomic, readonly) NSString* validationSummary;

- (instancetype)initWithFileListNodes:(NSArray*)nodes;

- (void)recomputePreview;
- (void)setActive:(BOOL)active forDisplayedItemAtIndex:(NSUInteger)row;
- (void)moveDisplayedItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void)executeWithUndoManager:(NSUndoManager*)undoManager completionHandler:(FileBatchRenameCompletionHandler)completionHandler;

@end
