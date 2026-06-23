// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileBatchRenameSession.h"

#import "CocoaCompatibility.h"
#import "FileBatchRenameItem.h"
#import "FileListNode.h"
#import "NSMutableArrayAdditions.h"
#import "RenameRules.h"
#import "Torrent.h"

static NSString* const kFileBatchRenameSessionErrorDomain = @"org.transmissionbt.batch-rename";

@interface FileBatchRenameOperation : NSObject

@property(nonatomic) FileListNode* node;
@property(nonatomic, copy) NSString* fromName;
@property(nonatomic, copy) NSString* toName;

+ (instancetype)operationWithNode:(FileListNode*)node fromName:(NSString*)fromName toName:(NSString*)toName;
- (FileBatchRenameOperation*)inverseOperation;

@end

@implementation FileBatchRenameOperation

+ (instancetype)operationWithNode:(FileListNode*)node fromName:(NSString*)fromName toName:(NSString*)toName
{
    FileBatchRenameOperation* operation = [[self alloc] init];
    operation.node = node;
    operation.fromName = fromName;
    operation.toName = toName;
    return operation;
}

- (FileBatchRenameOperation*)inverseOperation
{
    return [FileBatchRenameOperation operationWithNode:self.node fromName:self.toName toName:self.fromName];
}

@end

typedef void (^FileBatchRenameErrorCompletionHandler)(NSError* error);

@interface FileBatchRenameSession ()

@property(nonatomic) NSMutableArray* mutableItems;
@property(nonatomic, copy) NSArray* displayedItems;
@property(nonatomic) BOOL canRename;
@property(nonatomic, copy) NSString* validationSummary;
@property(nonatomic, TR_OBJC_WEAK) NSUndoManager* undoManager;

@end

@implementation FileBatchRenameSession

- (instancetype)initWithFileListNodes:(NSArray*)nodes
{
    NSParameterAssert(nodes.count > 1);

    if ((self = [super init]))
    {
        _mutableItems = [[NSMutableArray alloc] initWithCapacity:nodes.count];
        NSUInteger index = 0;
        for (FileListNode* node in nodes)
        {
            [_mutableItems addObject:[[FileBatchRenameItem alloc] initWithFileListNode:node visibleOrderIndex:index++]];
        }

        _config = [RenameRuleConfig defaultConfig];
        _rule = [RenameRules replaceRuleForMode:_config.replaceMode];
        [self recomputePreview];
    }
    return self;
}

- (NSArray*)items
{
    return self.mutableItems;
}

- (void)setRule:(id<RenameRule>)rule
{
    _rule = rule;
    [self recomputePreview];
}

- (void)setConfig:(RenameRuleConfig*)config
{
    _config = config;
    [self recomputePreview];
}

- (void)recomputePreview
{
    NSString* configError = nil;
    BOOL configValid = [self.rule validateConfig:self.config errorMessage:&configError];

    NSUInteger activeRowIndex = 0;
    for (FileBatchRenameItem* item in self.mutableItems)
    {
        RenameRuleResult* result = configValid ?
            [self.rule previewNameForOriginalName:item.originalName config:self.config rowIndex:activeRowIndex] :
            [RenameRuleResult resultWithGeneratedName:item.originalName errorMessage:configError];
        item.generatedName = result.generatedName ?: item.originalName;
        item.validationMessage = item.active ? result.errorMessage : nil;

        if (item.active)
        {
            activeRowIndex++;
        }
    }

    [self validateItems];
    [self updateDisplayedItemsAndRenameState];
}

- (void)setActive:(BOOL)active forDisplayedItemAtIndex:(NSUInteger)row
{
    if (row >= self.displayedItems.count)
    {
        return;
    }

    FileBatchRenameItem* item = [self.displayedItems objectAtIndex:row];
    item.active = active;
    [self recomputePreview];
}

- (void)moveDisplayedItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex >= self.displayedItems.count || toIndex > self.displayedItems.count || fromIndex == toIndex)
    {
        return;
    }

    FileBatchRenameItem* item = [self.displayedItems objectAtIndex:fromIndex];
    NSUInteger oldIndex = [self.mutableItems indexOfObjectIdenticalTo:item];
    NSUInteger newIndex = toIndex == self.displayedItems.count ? self.mutableItems.count :
        [self.mutableItems indexOfObjectIdenticalTo:[self.displayedItems objectAtIndex:toIndex]];

    if (oldIndex == NSNotFound || newIndex == NSNotFound || oldIndex == newIndex)
    {
        return;
    }

    if (oldIndex < newIndex)
    {
        newIndex--;
    }
    [self.mutableItems moveObjectAtIndex:oldIndex toIndex:newIndex];
    [self recomputePreview];
}

- (void)executeWithUndoManager:(NSUndoManager*)undoManager completionHandler:(FileBatchRenameCompletionHandler)completionHandler
{
    [self recomputePreview];
    if (!self.canRename)
    {
        if (completionHandler != nil)
        {
            completionHandler(NO, self.validationSummary);
        }
        return;
    }

    NSMutableArray* operations = [NSMutableArray array];
    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (item.active && item.valid && item.changed)
        {
            [operations addObject:[FileBatchRenameOperation operationWithNode:item.node fromName:item.originalName toName:item.generatedName]];
        }
    }

    [self executeOperations:operations rollbackOnFailure:YES completionHandler:^(BOOL success, NSString* errorMessage) {
        if (success && undoManager != nil)
        {
            self.undoManager = undoManager;
            [self registerUndoForOperations:operations];
        }

        if (completionHandler != nil)
        {
            completionHandler(success, errorMessage);
        }
    }];
}

#pragma mark - Validation

- (void)validateItems
{
    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (!item.active)
        {
            item.validationMessage = nil;
            continue;
        }

        if (item.validationMessage.length > 0)
        {
            continue;
        }

        NSString* generatedName = item.generatedName;
        if (generatedName.length == 0)
        {
            item.validationMessage = NSLocalizedString(@"Destination name is empty.", "Batch rename validation error");
        }
        else if ([generatedName isEqualToString:@"."] || [generatedName isEqualToString:@".."])
        {
            item.validationMessage = NSLocalizedString(@"Destination name is reserved.", "Batch rename validation error");
        }
        else if ([generatedName rangeOfString:@"/"].location != NSNotFound || [generatedName rangeOfString:@":"].location != NSNotFound)
        {
            item.validationMessage = NSLocalizedString(@"Destination name contains a path separator.", "Batch rename validation error");
        }
    }

    [self validateAncestorDescendantConflicts];
    [self validateSiblingCollisions];
}

- (void)validateAncestorDescendantConflicts
{
    NSMutableArray* activeFolders = [NSMutableArray array];
    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (item.active && item.node.isFolder)
        {
            [activeFolders addObject:item];
        }
    }

    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (!item.active || !item.valid)
        {
            continue;
        }

        for (FileBatchRenameItem* folderItem in activeFolders)
        {
            if (folderItem == item)
            {
                continue;
            }

            if ([self item:item isDescendantOfFolderItem:folderItem])
            {
                item.validationMessage = NSLocalizedString(@"A selected folder already contains this item.", "Batch rename validation error");
                break;
            }
        }
    }
}

- (BOOL)item:(FileBatchRenameItem*)item isDescendantOfFolderItem:(FileBatchRenameItem*)folderItem
{
    NSArray* folderComponents = folderItem.originalFullPath.pathComponents;
    NSArray* itemComponents = item.originalFullPath.pathComponents;
    if (itemComponents.count <= folderComponents.count)
    {
        return NO;
    }

    for (NSUInteger index = 0; index < folderComponents.count; ++index)
    {
        if (![[folderComponents objectAtIndex:index] isEqualToString:[itemComponents objectAtIndex:index]])
        {
            return NO;
        }
    }
    return YES;
}

- (void)validateSiblingCollisions
{
    NSMutableDictionary* occupiedNamesByParent = [NSMutableDictionary dictionary];
    NSArray* allNodes = [self allTorrentNodes];

    for (FileListNode* node in allNodes)
    {
        NSMutableDictionary* occupiedNames = [occupiedNamesByParent objectForKey:node.path];
        if (occupiedNames == nil)
        {
            occupiedNames = [NSMutableDictionary dictionary];
            [occupiedNamesByParent setObject:occupiedNames forKey:node.path];
        }
        [occupiedNames setObject:node forKey:node.name.lowercaseString];
    }

    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (!item.active || !item.valid || !item.changed)
        {
            continue;
        }

        NSMutableDictionary* occupiedNames = [occupiedNamesByParent objectForKey:item.originalPath];
        if (occupiedNames == nil)
        {
            occupiedNames = [NSMutableDictionary dictionary];
            [occupiedNamesByParent setObject:occupiedNames forKey:item.originalPath];
        }

        [occupiedNames removeObjectForKey:item.originalName.lowercaseString];

        NSString* destinationKey = item.generatedName.lowercaseString;
        FileListNode* collidingNode = [occupiedNames objectForKey:destinationKey];
        if (collidingNode != nil && collidingNode != item.node)
        {
            item.validationMessage = [self selectedItemForNode:collidingNode] != nil ?
                NSLocalizedString(@"Another selected item still has this name.", "Batch rename validation error") :
                NSLocalizedString(@"A sibling item already has this name.", "Batch rename validation error");
            [occupiedNames setObject:item.node forKey:item.originalName.lowercaseString];
            continue;
        }

        [occupiedNames setObject:item.node forKey:destinationKey];
    }
}

- (FileBatchRenameItem*)selectedItemForNode:(FileListNode*)node
{
    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (item.node == node)
        {
            return item;
        }
    }
    return nil;
}

- (NSArray*)allTorrentNodes
{
    FileBatchRenameItem* firstItem = [self.mutableItems objectAtIndex:0];
    NSMutableArray* nodes = [NSMutableArray array];
    for (FileListNode* node in firstItem.node.torrent.fileList)
    {
        [self addNodeAndDescendants:node toArray:nodes];
    }
    return nodes;
}

- (void)addNodeAndDescendants:(FileListNode*)node toArray:(NSMutableArray*)nodes
{
    [nodes addObject:node];
    if (node.isFolder)
    {
        for (FileListNode* childNode in node.children)
        {
            [self addNodeAndDescendants:childNode toArray:nodes];
        }
    }
}

- (void)updateDisplayedItemsAndRenameState
{
    NSMutableArray* displayedItems = [NSMutableArray array];
    BOOL hasActiveChangedValidItem = NO;
    BOOL hasActiveInvalidItem = NO;
    NSString* firstValidationMessage = nil;

    for (FileBatchRenameItem* item in self.mutableItems)
    {
        if (item.visible)
        {
            [displayedItems addObject:item];
        }

        if (item.active && !item.valid)
        {
            hasActiveInvalidItem = YES;
            if (firstValidationMessage.length == 0)
            {
                firstValidationMessage = item.validationMessage;
            }
        }
        else if (item.active && item.valid && item.changed)
        {
            hasActiveChangedValidItem = YES;
        }
    }

    self.displayedItems = displayedItems;
    self.canRename = hasActiveChangedValidItem && !hasActiveInvalidItem;

    if (hasActiveInvalidItem)
    {
        self.validationSummary = firstValidationMessage.length > 0 ?
            firstValidationMessage :
            NSLocalizedString(@"Uncheck or edit highlighted rows.", "Batch rename validation status");
    }
    else
    {
        self.validationSummary = @"";
    }
}

#pragma mark - Execution

- (void)executeOperations:(NSArray*)operations
        rollbackOnFailure:(BOOL)rollbackOnFailure
        completionHandler:(FileBatchRenameCompletionHandler)completionHandler
{
    NSMutableArray* completedOperations = [NSMutableArray array];
    [self executeOperations:operations atIndex:0 completedOperations:completedOperations completionHandler:^(NSError* error) {
        if (error == nil)
        {
            if (completionHandler != nil)
            {
                completionHandler(YES, nil);
            }
            return;
        }

        if (!rollbackOnFailure || completedOperations.count == 0)
        {
            if (completionHandler != nil)
            {
                completionHandler(NO, error.localizedDescription);
            }
            return;
        }

        [self rollbackCompletedOperations:completedOperations originalError:error completionHandler:completionHandler];
    }];
}

- (void)executeOperations:(NSArray*)operations
                  atIndex:(NSUInteger)index
      completedOperations:(NSMutableArray*)completedOperations
        completionHandler:(FileBatchRenameErrorCompletionHandler)completionHandler
{
    if (index >= operations.count)
    {
        completionHandler(nil);
        return;
    }

    FileBatchRenameOperation* operation = [operations objectAtIndex:index];
    [self executeOperation:operation completionHandler:^(NSError* error) {
        if (error != nil)
        {
            completionHandler(error);
            return;
        }

        [completedOperations addObject:operation];
        [self executeOperations:operations atIndex:index + 1 completedOperations:completedOperations completionHandler:completionHandler];
    }];
}

- (void)rollbackCompletedOperations:(NSArray*)completedOperations
                       originalError:(NSError*)originalError
                   completionHandler:(FileBatchRenameCompletionHandler)completionHandler
{
    NSMutableArray* rollbackOperations = [NSMutableArray arrayWithCapacity:completedOperations.count];
    for (FileBatchRenameOperation* operation in [completedOperations reverseObjectEnumerator])
    {
        [rollbackOperations addObject:operation.inverseOperation];
    }

    [self executeOperations:rollbackOperations atIndex:0 completedOperations:[NSMutableArray array] completionHandler:^(NSError* rollbackError) {
        NSString* message = originalError.localizedDescription;
        if (rollbackError != nil)
        {
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ Rollback also failed: %@", "Batch rename execution error"),
                                                 message,
                                                 rollbackError.localizedDescription];
        }

        if (completionHandler != nil)
        {
            completionHandler(NO, message);
        }
    }];
}

- (void)executeOperation:(FileBatchRenameOperation*)operation completionHandler:(FileBatchRenameErrorCompletionHandler)completionHandler
{
    if ([operation.fromName isEqualToString:operation.toName])
    {
        completionHandler(nil);
        return;
    }

    if (![operation.node.name isEqualToString:operation.fromName])
    {
        completionHandler([self errorWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Expected \"%@\" but found \"%@\".", "Batch rename execution error"),
                                                                            operation.fromName,
                                                                            operation.node.name]]);
        return;
    }

    if ([self name:operation.fromName differsOnlyByCaseFromName:operation.toName])
    {
        [self executeCaseOnlyOperation:operation completionHandler:completionHandler];
        return;
    }

    [self renameNode:operation.node toName:operation.toName completionHandler:completionHandler];
}

- (void)executeCaseOnlyOperation:(FileBatchRenameOperation*)operation completionHandler:(FileBatchRenameErrorCompletionHandler)completionHandler
{
    NSString* temporaryName = [self temporaryNameForOperation:operation];
    FileBatchRenameOperation* temporaryOperation = [FileBatchRenameOperation operationWithNode:operation.node
                                                                                    fromName:operation.fromName
                                                                                      toName:temporaryName];
    FileBatchRenameOperation* finalOperation = [FileBatchRenameOperation operationWithNode:operation.node
                                                                                 fromName:temporaryName
                                                                                   toName:operation.toName];

    [self renameNode:temporaryOperation.node toName:temporaryOperation.toName completionHandler:^(NSError* temporaryError) {
        if (temporaryError != nil)
        {
            completionHandler(temporaryError);
            return;
        }

        [self renameNode:finalOperation.node toName:finalOperation.toName completionHandler:^(NSError* finalError) {
            if (finalError == nil)
            {
                completionHandler(nil);
                return;
            }

            [self renameNode:temporaryOperation.node toName:temporaryOperation.fromName completionHandler:^(NSError* rollbackError) {
                if (rollbackError != nil)
                {
                    completionHandler([self errorWithMessage:[NSString stringWithFormat:NSLocalizedString(
                                                                  @"%@ Temporary case-only rollback also failed: %@",
                                                                  "Batch rename execution error"),
                                                              finalError.localizedDescription,
                                                              rollbackError.localizedDescription]]);
                }
                else
                {
                    completionHandler(finalError);
                }
            }];
        }];
    }];
}

- (void)renameNode:(FileListNode*)node toName:(NSString*)name completionHandler:(FileBatchRenameErrorCompletionHandler)completionHandler
{
    [node.torrent renameFileNode:node withName:name completionHandler:^(BOOL didRename) {
        if (didRename)
        {
            completionHandler(nil);
        }
        else
        {
            completionHandler([self errorWithMessage:NSLocalizedString(@"The rename failed.", "Batch rename execution error")]);
        }
    }];
}

- (NSString*)temporaryNameForOperation:(FileBatchRenameOperation*)operation
{
    for (NSUInteger attempt = 0; attempt < 100; ++attempt)
    {
        NSString* candidate = [NSString stringWithFormat:@".%@.transmission-rename-%08x", operation.fromName, arc4random()];
        if (![self siblingNameExists:candidate forNode:operation.node])
        {
            return candidate;
        }
    }

    return [NSString stringWithFormat:@".%@.transmission-rename", operation.fromName];
}

- (BOOL)siblingNameExists:(NSString*)name forNode:(FileListNode*)node
{
    for (FileListNode* sibling in [self allTorrentNodes])
    {
        if (sibling != node && [sibling.path isEqualToString:node.path] && [sibling.name caseInsensitiveCompare:name] == NSOrderedSame)
        {
            return YES;
        }
    }
    return NO;
}

- (BOOL)name:(NSString*)firstName differsOnlyByCaseFromName:(NSString*)secondName
{
    return ![firstName isEqualToString:secondName] && [firstName caseInsensitiveCompare:secondName] == NSOrderedSame;
}

#pragma mark - Undo

- (void)registerUndoForOperations:(NSArray*)operations
{
    NSArray* inverseOperations = [self inverseOperationsForOperations:operations];
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoRedoBatchRename:) object:inverseOperations];
    [self.undoManager setActionName:NSLocalizedString(@"Batch Rename", "Batch rename undo action")];
}

- (NSArray*)inverseOperationsForOperations:(NSArray*)operations
{
    NSMutableArray* inverseOperations = [NSMutableArray arrayWithCapacity:operations.count];
    for (FileBatchRenameOperation* operation in [operations reverseObjectEnumerator])
    {
        [inverseOperations addObject:operation.inverseOperation];
    }
    return inverseOperations;
}

- (void)performUndoRedoBatchRename:(NSArray*)operations
{
    [self executeOperations:operations rollbackOnFailure:NO completionHandler:^(BOOL success, NSString* errorMessage) {
        if (success)
        {
            [self registerUndoForOperations:operations];
        }
        else
        {
            [self showFailureMessage:errorMessage];
        }
    }];
}

- (void)showFailureMessage:(NSString*)message
{
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Batch rename failed.", "Batch rename alert title");
    alert.informativeText = message ?: @"";
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
}

- (NSError*)errorWithMessage:(NSString*)message
{
    NSDictionary* userInfo = @{ NSLocalizedDescriptionKey : message ?: NSLocalizedString(@"The rename failed.", "Batch rename execution error") };
    return [NSError errorWithDomain:kFileBatchRenameSessionErrorDomain code:1 userInfo:userInfo];
}

@end
