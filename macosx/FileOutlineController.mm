// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileOutlineController.h"
#import "CocoaCompatibility.h"
#import "Torrent.h"
#import "FileListNode.h"
#import "FileOutlineView.h"
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_8
#import "BaseFileNameCellView.h"
#endif
#import "FileOutlineItemDisplay.h"
#import "FilePriorityCell.h"
#import "FilePriorityCellView.h"
#import "FileCheckCellView.h"
#import "FileBatchRenameSheetController.h"
#import "FileBatchRenameSession.h"
#import "FileRenameSheetController.h"
#import "NSMutableArrayAdditions.h"
#import "NSStringAdditions.h"

static CGFloat const kRowSmallHeight = 22.0;

typedef NS_ENUM(NSUInteger, FileCheckMenuTag) { //
    FileCheckMenuTagCheck,
    FileCheckMenuTagUncheck
};

typedef NS_ENUM(NSUInteger, FilePriorityMenuTag) { //
    FilePriorityMenuTagHigh,
    FilePriorityMenuTagNormal,
    FilePriorityMenuTagLow
};

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8
static NSString* TRFileOutlinePathTooltip(FileListNode* node)
{
    NSString* path = [node.torrent fileLocation:node];
    if (!path)
    {
        path = [node.path stringByAppendingPathComponent:node.name];
    }
    return path;
}
#endif

@interface FileOutlineController ()<NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuItemValidation>

@property(nonatomic) NSMutableArray* fFileList;

@property(nonatomic) IBOutlet FileOutlineView* fOutline;
@property(nonatomic, weak) NSUndoManager* batchRenameUndoManager;

@property(nonatomic, readonly) NSMenu* menu;

@end

@implementation FileOutlineController

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fFileList = _fFileList;
@synthesize fOutline = _fOutline;
@synthesize batchRenameUndoManager = _batchRenameUndoManager;
@synthesize torrent = _torrent;
@synthesize filterText = _filterText;
#endif

- (void)dealloc
{
    [self.batchRenameUndoManager removeAllActionsWithTarget:self];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.fFileList = [[NSMutableArray alloc] init];

    //set table header tool tips
    [self.fOutline tableColumnWithIdentifier:@"Check"].headerToolTip = NSLocalizedString(@"Download", "file table -> header tool tip");
    [self.fOutline tableColumnWithIdentifier:@"Priority"].headerToolTip = NSLocalizedString(@"Priority", "file table -> header tool tip");

    self.fOutline.menu = self.menu;
    self.fOutline.target = self;
    self.fOutline.doubleAction = @selector(revealFile:);

    self.torrent = nil;
}

- (FileOutlineView*)outlineView
{
    return _fOutline;
}

- (void)setTorrent:(Torrent*)torrent
{
    _torrent = torrent;

    [self.fFileList setArray:torrent.fileList ?: @[]];

    self.filterText = nil;

    [self.fOutline reloadData];
    [self.fOutline deselectAll:nil]; //do this after reloading the data #4575
}

- (void)setFilterText:(NSString*)text
{
    NSArray* components = [text nonEmptyComponentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!components || components.count == 0)
    {
        text = nil;
        components = nil;
    }

    if ((!text && !_filterText) || (text && _filterText && [text isEqualToString:_filterText]))
    {
        return;
    }

    [self.fOutline beginUpdates];

    NSUInteger currentIndex = 0, totalCount = 0;
    NSMutableArray* itemsToAdd = [NSMutableArray array];
    NSMutableIndexSet* itemsToAddIndexes = [NSMutableIndexSet indexSet];

    NSMutableDictionary* removedIndexesForParents = nil; //ugly, but we can't modify the actual file nodes

    NSArray* tempList = !text ? self.torrent.fileList : self.torrent.flatFileList;
    for (FileListNode* item in tempList)
    {
        __block BOOL filter = NO;
        if (components)
        {
            [components enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString* obj, NSUInteger /*idx*/, BOOL* stop) {
                if ([item.name rangeOfString:obj options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location == NSNotFound)
                {
                    filter = YES;
                    *stop = YES;
                }
            }];
        }

        if (!filter)
        {
            FileListNode* parent = nil;
            NSUInteger previousIndex = !item.isFolder ?
                [self findFileNode:item inList:self.fFileList
                         atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(currentIndex, self.fFileList.count - currentIndex)]
                     currentParent:nil
                       finalParent:&parent] :
                NSNotFound;

            if (previousIndex == NSNotFound)
            {
                [itemsToAdd addObject:item];
                [itemsToAddIndexes addIndex:totalCount];
            }
            else
            {
                BOOL move = YES;
                if (!parent)
                {
                    if (previousIndex != currentIndex)
                    {
                        [self.fFileList moveObjectAtIndex:previousIndex toIndex:currentIndex];
                    }
                    else
                    {
                        move = NO;
                    }
                }
                else
                {
                    [self.fFileList insertObject:item atIndex:currentIndex];

                    //figure out the index within the semi-edited table - UGLY
                    if (!removedIndexesForParents)
                    {
                        removedIndexesForParents = [NSMutableDictionary dictionary];
                    }

                    NSMutableIndexSet* removedIndexes = removedIndexesForParents[parent];
                    if (!removedIndexes)
                    {
                        removedIndexes = [NSMutableIndexSet indexSetWithIndex:previousIndex];
                        removedIndexesForParents[parent] = removedIndexes;
                    }
                    else
                    {
                        [removedIndexes addIndex:previousIndex];
                        previousIndex -= [removedIndexes countOfIndexesInRange:NSMakeRange(0, previousIndex)];
                    }
                }

                if (move)
                {
                    [self.fOutline moveItemAtIndex:previousIndex inParent:parent toIndex:currentIndex inParent:nil];
                }

                ++currentIndex;
            }

            ++totalCount;
        }
    }

    //remove trailing items - those are the unused
    if (currentIndex < self.fFileList.count)
    {
        NSRange const removeRange = NSMakeRange(currentIndex, self.fFileList.count - currentIndex);
        [self.fFileList removeObjectsInRange:removeRange];
        [self.fOutline removeItemsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:removeRange] inParent:nil
                              withAnimation:NSTableViewAnimationSlideDown];
    }

    //add new items
    [self.fFileList insertObjects:itemsToAdd atIndexes:itemsToAddIndexes];
    [self.fOutline insertItemsAtIndexes:itemsToAddIndexes inParent:nil withAnimation:NSTableViewAnimationSlideUp];

    [self.fOutline endUpdates];

    _filterText = text;
}

- (void)reloadVisibleRows
{
    NSRect visibleRect = self.fOutline.visibleRect;
    NSRange range = [self.fOutline rowsInRect:visibleRect];

    NSIndexSet* rowIndexes = [NSIndexSet indexSetWithIndexesInRange:range];
    NSIndexSet* columnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.fOutline.numberOfColumns)];

    [self.fOutline reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
    if (!item)
    {
        return self.fFileList ? self.fFileList.count : 0;
    }
    else
    {
        FileListNode* node = (FileListNode*)item;
        return node.isFolder ? node.children.count : 0;
    }
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
    return ((FileListNode*)item).isFolder;
}

- (id)outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
    return (item ? ((FileListNode*)item).children : self.fFileList)[index];
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8
- (id)outlineView:(NSOutlineView*)outlineView objectValueForTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
    FileListNode* node = (FileListNode*)item;
    NSString* identifier = tableColumn.identifier;

    if ([identifier isEqualToString:@"Name"])
    {
        return node;
    }
    if ([identifier isEqualToString:@"Check"])
    {
        return @([node.torrent checkForFiles:node.indexes]);
    }
    if ([identifier isEqualToString:@"Priority"])
    {
        return node;
    }

    return nil;
}

- (void)outlineView:(NSOutlineView*)outlineView
    willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn*)tableColumn
               item:(id)item
{
    FileListNode* node = (FileListNode*)item;
    NSString* identifier = tableColumn.identifier;

    if ([identifier isEqualToString:@"Check"])
    {
        [cell setEnabled:[self.torrent canChangeDownloadCheckForFiles:node.indexes]];
    }
    else if ([identifier isEqualToString:@"Priority"])
    {
        [cell setRepresentedObject:node];

        if ([cell isKindOfClass:[FilePriorityCell class]])
        {
            NSInteger hoveredRow = self.fOutline.hoveredRow;
            ((FilePriorityCell*)cell).hovered = hoveredRow != -1 && hoveredRow == [self.fOutline rowForItem:node];
        }
    }
}

- (void)outlineView:(NSOutlineView*)outlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn*)tableColumn
             byItem:(id)item
{
    if (![tableColumn.identifier isEqualToString:@"Check"])
    {
        return;
    }

    FileListNode* node = (FileListNode*)item;
    NSIndexSet* indexSet;
#if TR_MACOS_SDK_BEFORE_10_12
    if ([NSEvent modifierFlags] & NSAlternateKeyMask)
#else
    if (NSEvent.modifierFlags & NSEventModifierFlagOption)
#endif
    {
        indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.torrent.fileCount)];
    }
    else
    {
        indexSet = node.indexes;
    }

    [self.torrent setFileCheckState:[object intValue] != NSControlStateValueOff ? NSControlStateValueOn : NSControlStateValueOff
                         forIndexes:indexSet];
    [self reloadVisibleRows];

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateUI" object:nil];
}

- (NSString*)outlineView:(NSOutlineView*)outlineView
          toolTipForCell:(NSCell*)cell
                    rect:(NSRectPointer)rect
             tableColumn:(NSTableColumn*)tableColumn
                    item:(id)item
           mouseLocation:(NSPoint)mouseLocation
{
    FileListNode* node = (FileListNode*)item;
    NSString* identifier = tableColumn.identifier;

    if ([identifier isEqualToString:@"Name"])
    {
        return TRFileOutlinePathTooltip(node);
    }
    if ([identifier isEqualToString:@"Check"])
    {
        return TRFileOutlineCheckTooltip(cell.state);
    }
    if ([identifier isEqualToString:@"Priority"])
    {
        return TRFileOutlinePriorityTooltip([self.torrent filePrioritiesForIndexes:node.indexes]);
    }

    return nil;
}
#endif

#pragma mark - NSOutlineViewDelegate

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_8
- (NSView*)outlineView:(NSOutlineView*)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    NSString* identifier = tableColumn.identifier;
    FileListNode* node = (FileListNode*)item;

    if ([identifier isEqualToString:@"Name"])
    {
        BaseFileNameCellView* cellView = nil;

        if (node.isFolder)
        {
            cellView = [outlineView makeViewWithIdentifier:@"OnlyFolderCell" owner:self];
            if (!cellView)
            {
                cellView = [[FolderNameCellView alloc] initWithFrame:NSZeroRect];
                cellView.identifier = @"OnlyFolderCell";
            }
        }
        else
        {
            cellView = [outlineView makeViewWithIdentifier:@"OnlyFileCell" owner:self];
            if (!cellView)
            {
                cellView = [[FileNameCellView alloc] initWithFrame:NSZeroRect];
                cellView.identifier = @"OnlyFileCell";
            }
        }
        cellView.node = node;

        return cellView;
    }
    else if ([identifier isEqualToString:@"Priority"])
    {
        FilePriorityCellView* cellView = [outlineView makeViewWithIdentifier:@"PriorityCell" owner:self];
        if (!cellView)
        {
            cellView = [[FilePriorityCellView alloc] initWithFrame:NSZeroRect];
            cellView.identifier = @"PriorityCell";
        }
        cellView.node = node;

        return cellView;
    }
    else if ([identifier isEqualToString:@"Check"])
    {
        FileCheckCellView* cellView = [outlineView makeViewWithIdentifier:@"CheckCell" owner:self];
        if (!cellView)
        {
            cellView = [[FileCheckCellView alloc] initWithFrame:NSZeroRect];
            cellView.identifier = @"CheckCell";
        }
        cellView.node = node;

        return cellView;
    }

    return nil;
}
#endif

- (NSString*)outlineView:(NSOutlineView*)outlineView typeSelectStringForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    return ((FileListNode*)item).name;
}

- (void)outlineViewSelectionDidChange:(NSNotification*)notification
{
    [self reloadVisibleRows];
    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
    {
        [[QLPreviewPanel sharedPreviewPanel] reloadData];
    }
}

- (CGFloat)outlineView:(NSOutlineView*)outlineView heightOfRowByItem:(id)item
{
    if (((FileListNode*)item).isFolder)
    {
        return kRowSmallHeight;
    }
    else
    {
        return outlineView.rowHeight;
    }
}

#pragma mark - Actions

- (void)setCheck:(id)sender
{
    NSControlStateValue state = [sender tag] == FileCheckMenuTagUncheck ? NSControlStateValueOff : NSControlStateValueOn;

    NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
    NSMutableIndexSet* itemIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
    {
        FileListNode* item = [self.fOutline itemAtRow:i];
        [itemIndexes addIndexes:item.indexes];
    }

    [self.torrent setFileCheckState:state forIndexes:itemIndexes];

    [self reloadVisibleRows];
}

- (void)setOnlySelectedCheck:(id)sender
{
    NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
    NSMutableIndexSet* itemIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
    {
        FileListNode* item = [self.fOutline itemAtRow:i];
        [itemIndexes addIndexes:item.indexes];
    }

    [self.torrent setFileCheckState:NSControlStateValueOn forIndexes:itemIndexes];

    NSMutableIndexSet* remainingItemIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.torrent.fileCount)];
    [remainingItemIndexes removeIndexes:itemIndexes];
    [self.torrent setFileCheckState:NSControlStateValueOff forIndexes:remainingItemIndexes];

    [self reloadVisibleRows];
}

- (void)checkAll
{
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.torrent.fileCount)];
    [self.torrent setFileCheckState:NSControlStateValueOn forIndexes:indexSet];

    [self reloadVisibleRows];
}

- (void)uncheckAll
{
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.torrent.fileCount)];
    [self.torrent setFileCheckState:NSControlStateValueOff forIndexes:indexSet];

    [self reloadVisibleRows];
}

- (void)setPriority:(id)sender
{
    tr_priority_t priority;
    switch ([sender tag])
    {
    case FilePriorityMenuTagHigh:
        priority = TR_PRI_HIGH;
        break;
    case FilePriorityMenuTagNormal:
        priority = TR_PRI_NORMAL;
        break;
    case FilePriorityMenuTagLow:
        priority = TR_PRI_LOW;
        break;
    default:
        NSAssert1(NO, @"Unknown sender tag: %ld", [sender tag]);
        return;
    }

    NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
    NSMutableIndexSet* itemIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
    {
        FileListNode* item = [self.fOutline itemAtRow:i];
        [itemIndexes addIndexes:item.indexes];
    }

    [self.torrent setFilePriority:priority forIndexes:itemIndexes];

    [self reloadVisibleRows];
}

- (void)revealFile:(id)sender
{
    NSIndexSet* indexes = self.fOutline.selectedRowIndexes;
    NSMutableArray* paths = [NSMutableArray arrayWithCapacity:indexes.count];
    for (NSUInteger i = indexes.firstIndex; i != NSNotFound; i = [indexes indexGreaterThanIndex:i])
    {
        NSString* path = [self.torrent fileLocation:[self.fOutline itemAtRow:i]];
        if (path)
        {
            [paths addObject:[NSURL fileURLWithPath:path]];
        }
    }

    if (paths.count > 0)
    {
        TRActivateFileViewerSelectingURLs(paths);
    }
}

- (void)renameSelected:(id)sender
{
    NSIndexSet* indexes = self.fOutline.selectedRowIndexes;
    if (indexes.count == 0)
    {
        return;
    }

    if (indexes.count > 1)
    {
        NSMutableArray* nodes = [NSMutableArray arrayWithCapacity:indexes.count];
        for (NSUInteger i = indexes.firstIndex; i != NSNotFound; i = [indexes indexGreaterThanIndex:i])
        {
            [nodes addObject:[self.fOutline itemAtRow:i]];
        }

        Torrent* torrent = ((FileListNode*)[nodes objectAtIndex:0]).torrent;
        [FileBatchRenameSheetController presentSheetForFileListNodes:nodes
                                                      modalForWindow:self.fOutline.window
                                                   completionHandler:^(BOOL didRename, NSArray* operations) {
            if (didRename)
            {
                [self registerUndoForBatchRenameOperations:operations];
                [NSNotificationCenter.defaultCenter postNotificationName:@"ResetInspector" object:self
                                                                userInfo:@{ @"Torrent" : torrent }];
            }
        }];
        return;
    }

    FileListNode* node = [self.fOutline itemAtRow:indexes.firstIndex];
    Torrent* torrent = node.torrent;
    if (!torrent.folder)
    {
        [FileRenameSheetController presentSheetForTorrent:torrent modalForWindow:self.fOutline.window completionHandler:^(BOOL didRename) {
            if (didRename)
            {
                [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateTorrentsState" object:nil];
                [NSNotificationCenter.defaultCenter postNotificationName:@"ResetInspector" object:self
                                                                userInfo:@{ @"Torrent" : torrent }];
            }
        }];
    }
    else
    {
        [FileRenameSheetController presentSheetForFileListNode:node modalForWindow:self.fOutline.window completionHandler:^(BOOL didRename) {
#warning instead of calling reset inspector, just resort?
            if (didRename)
                [NSNotificationCenter.defaultCenter postNotificationName:@"ResetInspector" object:self
                                                                userInfo:@{ @"Torrent" : torrent }];
        }];
    }
}

#pragma mark - NSMenuItemValidation

#warning make real view controller (Leopard-only) so that Command-R will work
#if !TR_MACOS_SDK_BEFORE_11_0
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    if ([(id)item isKindOfClass:NSMenuItem.class])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [self validateMenuItem:(NSMenuItem*)item];
#pragma clang diagnostic pop
    }

    return YES;
}
#endif

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    if (!self.torrent)
    {
        return NO;
    }

    SEL action = menuItem.action;

    if (action == @selector(revealFile:))
    {
        NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
        for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
        {
            if ([self.torrent fileLocation:[self.fOutline itemAtRow:i]] != nil)
            {
                return YES;
            }
        }
        return NO;
    }

    if (action == @selector(setCheck:))
    {
        if (self.fOutline.numberOfSelectedRows == 0)
        {
            return NO;
        }

        NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
        NSMutableIndexSet* itemIndexes = [NSMutableIndexSet indexSet];
        for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
        {
            FileListNode* node = [self.fOutline itemAtRow:i];
            [itemIndexes addIndexes:node.indexes];
        }

        NSControlStateValue state = (menuItem.tag == FileCheckMenuTagCheck) ? NSControlStateValueOn : NSControlStateValueOff;
        return [self.torrent checkForFiles:itemIndexes] != state && [self.torrent canChangeDownloadCheckForFiles:itemIndexes];
    }

    if (action == @selector(setOnlySelectedCheck:))
    {
        if (self.fOutline.numberOfSelectedRows == 0)
        {
            return NO;
        }

        NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
        NSMutableIndexSet* itemIndexes = [NSMutableIndexSet indexSet];
        for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
        {
            FileListNode* node = [self.fOutline itemAtRow:i];
            [itemIndexes addIndexes:node.indexes];
        }

        return [self.torrent canChangeDownloadCheckForFiles:itemIndexes];
    }

    if (action == @selector(setPriority:))
    {
        if (self.fOutline.numberOfSelectedRows == 0)
        {
            menuItem.state = NSControlStateValueOff;
            return NO;
        }

        //determine which priorities are checked
        NSIndexSet* indexSet = self.fOutline.selectedRowIndexes;
        tr_priority_t priority;
        switch (menuItem.tag)
        {
        case FilePriorityMenuTagHigh:
            priority = TR_PRI_HIGH;
            break;
        case FilePriorityMenuTagNormal:
            priority = TR_PRI_NORMAL;
            break;
        case FilePriorityMenuTagLow:
            priority = TR_PRI_LOW;
            break;
        default:
            NSAssert1(NO, @"Unknown menuItem tag: %ld", menuItem.tag);
            return NO;
        }

        BOOL current = NO, canChange = NO;
        for (NSInteger i = indexSet.firstIndex; i != NSNotFound; i = [indexSet indexGreaterThanIndex:i])
        {
            FileListNode* node = [self.fOutline itemAtRow:i];
            NSIndexSet* fileIndexSet = node.indexes;
            if (![self.torrent canChangeDownloadCheckForFiles:fileIndexSet])
            {
                continue;
            }

            canChange = YES;
            if ([self.torrent hasFilePriority:priority forIndexes:fileIndexSet])
            {
                current = YES;
                break;
            }
        }

        menuItem.state = current ? NSControlStateValueOn : NSControlStateValueOff;
        return canChange;
    }

    if (action == @selector(renameSelected:))
    {
        menuItem.title = self.fOutline.numberOfSelectedRows > 1 ?
            [NSLocalizedString(@"Batch Rename", "File Outline -> Menu") stringByAppendingEllipsis] :
            [NSLocalizedString(@"Rename File", "File Outline -> Menu") stringByAppendingEllipsis];
        return self.fOutline.numberOfSelectedRows > 0;
    }

    return YES;
}

#pragma mark - Private

- (void)registerUndoForBatchRenameOperations:(NSArray*)operations
{
    if (operations.count == 0)
    {
        return;
    }

    NSUndoManager* undoManager = self.fOutline.window.undoManager;
    if (undoManager == nil)
    {
        undoManager = self.batchRenameUndoManager;
    }
    if (undoManager == nil)
    {
        return;
    }

    if (self.batchRenameUndoManager != nil && self.batchRenameUndoManager != undoManager)
    {
        [self.batchRenameUndoManager removeAllActionsWithTarget:self];
    }
    self.batchRenameUndoManager = undoManager;

    NSArray* inverseOperations = [self inverseBatchRenameOperationsForOperations:operations];
    [undoManager registerUndoWithTarget:self selector:@selector(performUndoRedoBatchRename:) object:inverseOperations];
    [undoManager setActionName:NSLocalizedString(@"Batch Rename", "Batch rename undo action")];
}

- (NSArray*)inverseBatchRenameOperationsForOperations:(NSArray*)operations
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
    // NSUndoManager records redo only while this method is still on the undo stack.
    [self registerUndoForBatchRenameOperations:operations];

    [FileBatchRenameSession executeOperations:operations rollbackOnFailure:NO completionHandler:^(BOOL success, NSString* errorMessage) {
        if (success)
        {
            [self postBatchRenameUpdateForOperations:operations];
        }
        else
        {
            [self.batchRenameUndoManager removeAllActionsWithTarget:self];
            [self showBatchRenameFailureMessage:errorMessage];
        }
    }];
}

- (void)postBatchRenameUpdateForOperations:(NSArray*)operations
{
    if (operations.count == 0)
    {
        return;
    }

    FileBatchRenameOperation* operation = [operations objectAtIndex:0];
    Torrent* torrent = operation.node.torrent;
    if (torrent != nil)
    {
        [NSNotificationCenter.defaultCenter postNotificationName:@"ResetInspector" object:self userInfo:@{ @"Torrent" : torrent }];
    }
}

- (void)showBatchRenameFailureMessage:(NSString*)message
{
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Batch rename failed.", "Batch rename alert title");
    alert.informativeText = message ?: @"";
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
}

- (NSMenu*)menu
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];

    //check and uncheck
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check Selected", "File Outline -> Menu")
                                                  action:@selector(setCheck:)
                                           keyEquivalent:@""];
    if (@available(macOS 26.0, *))
    {
        item.image = TRImageForSystemSymbol(@"checkmark.circle", nil);
    }
    item.target = self;
    item.tag = FileCheckMenuTagCheck;
    [menu addItem:item];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Uncheck Selected", "File Outline -> Menu")
                                      action:@selector(setCheck:)
                               keyEquivalent:@""];
    if (@available(macOS 26.0, *))
    {
        item.image = TRImageForSystemSymbol(@"circle", nil);
    }
    item.target = self;
    item.tag = FileCheckMenuTagUncheck;
    [menu addItem:item];

    //only check selected
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Only Check Selected", "File Outline -> Menu")
                                      action:@selector(setOnlySelectedCheck:)
                               keyEquivalent:@""];
    if (@available(macOS 26.0, *))
    {
        item.image = TRImageForSystemSymbol(@"checkmark.circle.dotted", nil);
    }
    item.target = self;
    [menu addItem:item];

    [menu addItem:[NSMenuItem separatorItem]];

    //priority
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Priority", "File Outline -> Menu") action:NULL keyEquivalent:@""];
    NSMenu* priorityMenu = [[NSMenu alloc] initWithTitle:@""];
    if (@available(macOS 26.0, *))
    {
        item.image = TRImageForSystemSymbol(@"chevron.up.chevron.down", nil);
    }
    item.submenu = priorityMenu;
    [menu addItem:item];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"High", "File Outline -> Priority Menu")
                                      action:@selector(setPriority:)
                               keyEquivalent:@""];
    item.target = self;
    item.tag = FilePriorityMenuTagHigh;
    item.image = [NSImage imageNamed:@"PriorityHighTemplate"];
    [priorityMenu addItem:item];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Normal", "File Outline -> Priority Menu")
                                      action:@selector(setPriority:)
                               keyEquivalent:@""];
    item.target = self;
    item.tag = FilePriorityMenuTagNormal;
    item.image = [NSImage imageNamed:@"PriorityNormalTemplate"];
    [priorityMenu addItem:item];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Low", "File Outline -> Priority Menu")
                                      action:@selector(setPriority:)
                               keyEquivalent:@""];
    item.target = self;
    item.tag = FilePriorityMenuTagLow;
    item.image = [NSImage imageNamed:@"PriorityLowTemplate"];
    [priorityMenu addItem:item];

    [menu addItem:[NSMenuItem separatorItem]];

    //reveal in finder
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show in Finder", "File Outline -> Menu")
                                      action:@selector(revealFile:)
                               keyEquivalent:@""];
    if (@available(macOS 26.0, *))
    {
        item.image = TRImageForSystemSymbol(@"finder", nil);
    }
    item.target = self;
    [menu addItem:item];

    [menu addItem:[NSMenuItem separatorItem]];

    //rename
    item = [[NSMenuItem alloc] initWithTitle:[NSLocalizedString(@"Rename File", "File Outline -> Menu") stringByAppendingEllipsis]
                                      action:@selector(renameSelected:)
                               keyEquivalent:@""];
    if (@available(macOS 26.0, *))
    {
        item.image = TRImageForSystemSymbol(@"pencil", nil);
    }
    item.target = self;
    [menu addItem:item];

    return menu;
}

- (NSUInteger)findFileNode:(FileListNode*)node
                    inList:(NSArray*)list
                 atIndexes:(NSIndexSet*)indexes
             currentParent:(FileListNode*)currentParent
               finalParent:(FileListNode* __autoreleasing*)parent
{
    NSAssert(!node.isFolder, @"Looking up folder node!");

    __block FileListNode* retNode;
    __block NSUInteger retIndex = NSNotFound;

    using FindFileNode = void (^)(FileListNode*, NSArray*, NSIndexSet*, FileListNode*);
    __block __weak FindFileNode weakFindFileNode;
    FindFileNode findFileNode;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
    weakFindFileNode = findFileNode = ^(FileListNode* node, NSArray* list, NSIndexSet* indexes, FileListNode* currentParent) {
#pragma clang diagnostic pop
        [list enumerateObjectsAtIndexes:indexes options:NSEnumerationConcurrent
                             usingBlock:^(FileListNode* checkNode, NSUInteger index, BOOL* stop) {
                                 if ([checkNode.indexes containsIndex:node.indexes.firstIndex])
                                 {
                                     if (!checkNode.isFolder)
                                     {
                                         NSAssert([checkNode isEqualTo:node], @"Expected file nodes to be equal: %@ %@", checkNode, node);
                                         retNode = currentParent;
                                         retIndex = index;
                                     }
                                     else
                                     {
                                         weakFindFileNode(
                                             node,
                                             checkNode.children,
                                             [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, checkNode.children.count)],
                                             checkNode);
                                         NSAssert(retIndex != NSNotFound, @"We didn't find an expected file node.");
                                     }
                                     *stop = YES;
                                 }
                             }];
    };
    findFileNode(node, list, indexes, currentParent);

    if (retNode)
    {
        *parent = retNode;
    }
    return retIndex;
}

@end
