// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class Torrent;

@interface GroupsController : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSMutableArray* _fGroups;
}
#endif

@property(nonatomic, class, readonly) GroupsController* groups;

@property(nonatomic, readonly) NSInteger numberOfGroups;

- (NSInteger)rowValueForIndex:(NSInteger)index;
- (NSInteger)indexForRow:(NSInteger)row;

- (NSString*)nameForIndex:(NSInteger)index;
- (void)setName:(NSString*)name forIndex:(NSInteger)index;

- (NSImage*)imageForIndex:(NSInteger)index;

- (NSColor*)colorForIndex:(NSInteger)index;
- (void)setColor:(NSColor*)color forIndex:(NSInteger)index;

- (BOOL)usesCustomDownloadLocationForIndex:(NSInteger)index;
- (void)setUsesCustomDownloadLocation:(BOOL)useCustomLocation forIndex:(NSInteger)index;

- (NSString*)customDownloadLocationForIndex:(NSInteger)index;
- (void)setCustomDownloadLocation:(NSString*)location forIndex:(NSInteger)index;

- (BOOL)usesAutoAssignRulesForIndex:(NSInteger)index;
- (void)setUsesAutoAssignRules:(BOOL)useAutoAssignRules forIndex:(NSInteger)index;

- (NSPredicate*)autoAssignRulesForIndex:(NSInteger)index;
- (void)setAutoAssignRules:(NSPredicate*)predicate forIndex:(NSInteger)index;

- (NSString*)announcedClientIdentityForIndex:(NSInteger)index;
- (void)setAnnouncedClientIdentity:(NSString*)identity forIndex:(NSInteger)index;

- (void)addNewGroup;
- (void)removeGroupWithRowIndex:(NSInteger)row;

- (void)moveGroupAtRow:(NSInteger)oldRow toRow:(NSInteger)newRow;

- (NSMenu*)groupMenuWithTarget:(id)target action:(SEL)action isSmall:(BOOL)small;

- (NSInteger)groupIndexForTorrent:(Torrent*)torrent;
@end
