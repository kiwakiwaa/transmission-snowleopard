// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileBatchRenameItem.h"

#import "FileListNode.h"

@implementation FileBatchRenameItem

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize node = _node;
@synthesize originalName = _originalName;
@synthesize originalPath = _originalPath;
@synthesize visibleOrderIndex = _visibleOrderIndex;
@synthesize active = _active;
@synthesize generatedName = _generatedName;
@synthesize validationMessage = _validationMessage;
#endif

- (instancetype)initWithFileListNode:(FileListNode*)node visibleOrderIndex:(NSUInteger)visibleOrderIndex
{
    NSParameterAssert(node != nil);

    if ((self = [super init]))
    {
        _node = node;
        _originalName = [node.name copy];
        _originalPath = [node.path copy];
        _visibleOrderIndex = visibleOrderIndex;
        _active = YES;
        _generatedName = _originalName;
    }
    return self;
}

- (BOOL)valid
{
    return self.validationMessage.length == 0;
}

- (BOOL)changed
{
    return ![self.generatedName isEqualToString:self.originalName];
}

- (BOOL)visible
{
    return YES;
}

- (NSString*)originalFullPath
{
    return [self.originalPath stringByAppendingPathComponent:self.originalName];
}

@end
