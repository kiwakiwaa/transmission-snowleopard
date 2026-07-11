// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#import <AppKit/AppKit.h>
#else
#import <Foundation/Foundation.h>
#endif

@class Torrent;

@interface FileListNode : NSObject<NSCopying>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSString* _name;
    NSString* _path;
    __weak Torrent* _torrent;
    uint64_t _size;
    BOOL _isFolder;
    NSMutableArray* _children;
    NSMutableIndexSet* _indexesInternal;
    NSImage* _iconInternal;
}
#endif

@property(nonatomic, readonly) NSString* name;
@property(nonatomic, readonly) NSString* path;

@property(nonatomic, weak, readonly) Torrent* torrent;

@property(nonatomic, readonly) uint64_t size;
@property(nonatomic, readonly) NSImage* icon;
@property(nonatomic, readonly) BOOL isFolder;
@property(nonatomic, readonly) NSMutableArray* children;

@property(nonatomic, readonly) NSIndexSet* indexes;

- (instancetype)initWithFolderName:(NSString*)name path:(NSString*)path torrent:(Torrent*)torrent;
- (instancetype)initWithFileName:(NSString*)name
                            path:(NSString*)path
                            size:(uint64_t)size
                           index:(NSUInteger)index
                         torrent:(Torrent*)torrent;

- (void)insertChild:(FileListNode*)child;
- (void)insertIndex:(NSUInteger)index withSize:(uint64_t)size;

@property(nonatomic, readonly) NSString* description;

- (BOOL)updateFromOldName:(NSString*)oldName toNewName:(NSString*)newName inPath:(NSString*)path;

@end
