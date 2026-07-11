// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "Badger.h"
#import "BadgeView.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

@interface Badger ()

@property(nonatomic, readonly) NSMutableSet* fHashes;

@end

@implementation Badger

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fHashes = _fHashes;
#endif

- (instancetype)init
{
    if ((self = [super init]))
    {
        BadgeView* view = [[BadgeView alloc] init];
        [[NSApp dockTile] setContentView:view];

        _fHashes = [[NSMutableSet alloc] init];
    }

    return self;
}

- (void)updateBadgeWithDownload:(CGFloat)downloadRate upload:(CGFloat)uploadRate
{
    CGFloat const displayDlRate = [NSUserDefaults.standardUserDefaults boolForKey:@"BadgeDownloadRate"] ? downloadRate : 0.0;
    CGFloat const displayUlRate = [NSUserDefaults.standardUserDefaults boolForKey:@"BadgeUploadRate"] ? uploadRate : 0.0;

    //only update if the badged values change
    if ([(BadgeView*)[[NSApp dockTile] contentView] setRatesWithDownload:displayDlRate upload:displayUlRate])
    {
        [[NSApp dockTile] display];
    }
}

- (void)addCompletedTorrent:(Torrent*)torrent
{
    NSParameterAssert(torrent != nil);

    [self.fHashes addObject:torrent.hashString];
    [[NSApp dockTile] setBadgeLabel:[NSString localizedStringWithFormat:@"%lu", self.fHashes.count]];
}

- (void)removeTorrent:(Torrent*)torrent
{
    if ([self.fHashes member:torrent.hashString])
    {
        [self.fHashes removeObject:torrent.hashString];
        if (self.fHashes.count > 0)
        {
            [[NSApp dockTile] setBadgeLabel:[NSString localizedStringWithFormat:@"%lu", self.fHashes.count]];
        }
        else
        {
            [[NSApp dockTile] setBadgeLabel:@""];
        }
    }
}

- (void)clearCompleted
{
    if (self.fHashes.count > 0)
    {
        [self.fHashes removeAllObjects];
        [[NSApp dockTile] setBadgeLabel:@""];
    }
}

@end
