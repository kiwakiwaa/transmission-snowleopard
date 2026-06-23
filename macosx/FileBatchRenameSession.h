// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#import "RenameRule.h"

@class FileBatchRenameItem;
@class FileListNode;

typedef void (^FileBatchRenameCompletionHandler)(BOOL success, NSString* errorMessage);
typedef void (^FileBatchRenameExecutionCompletionHandler)(BOOL success, NSString* errorMessage, NSArray* operations);

@interface FileBatchRenameOperation : NSObject

@property(nonatomic, readonly) FileListNode* node;
@property(nonatomic, copy, readonly) NSString* fromName;
@property(nonatomic, copy, readonly) NSString* toName;

+ (instancetype)operationWithNode:(FileListNode*)node fromName:(NSString*)fromName toName:(NSString*)toName;
- (FileBatchRenameOperation*)inverseOperation;

@end

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
- (void)executeWithCompletionHandler:(FileBatchRenameExecutionCompletionHandler)completionHandler;

+ (void)executeOperations:(NSArray*)operations
        rollbackOnFailure:(BOOL)rollbackOnFailure
        completionHandler:(FileBatchRenameCompletionHandler)completionHandler;

@end
