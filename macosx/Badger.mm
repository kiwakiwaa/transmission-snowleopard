// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "Badger.h"
#import "BadgeView.h"
#import "LegacyDockTile.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

#include <libtransmission/macos-version.h>

@interface Badger ()

@property(nonatomic, readonly) NSMutableSet* fHashes;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
@property(nonatomic, readonly) LegacyDockTile* fLegacyDockTile;
#endif

@end

@implementation Badger

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fHashes = _fHashes;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
@synthesize fLegacyDockTile = _fLegacyDockTile;
#endif
#endif

- (instancetype)init
{
    if ((self = [super init]))
    {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
        _fLegacyDockTile = [[LegacyDockTile alloc] initWithOriginalIcon:[NSApp applicationIconImage]];
#else
        BadgeView* view = [[BadgeView alloc] init];
        [[NSApp dockTile] setContentView:view];
#endif

        _fHashes = [[NSMutableSet alloc] init];
    }

    return self;
}

- (void)updateBadgeWithDownload:(CGFloat)downloadRate upload:(CGFloat)uploadRate
{
    CGFloat const displayDlRate = [NSUserDefaults.standardUserDefaults boolForKey:@"BadgeDownloadRate"] ? downloadRate : 0.0;
    CGFloat const displayUlRate = [NSUserDefaults.standardUserDefaults boolForKey:@"BadgeUploadRate"] ? uploadRate : 0.0;

    //only update if the badged values change
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    if ([self.fLegacyDockTile setRatesWithDownload:displayDlRate upload:displayUlRate])
    {
        [self.fLegacyDockTile display];
    }
#else
    if ([(BadgeView*)[[NSApp dockTile] contentView] setRatesWithDownload:displayDlRate upload:displayUlRate])
    {
        [[NSApp dockTile] display];
    }
#endif
}

- (void)addCompletedTorrent:(Torrent*)torrent
{
    NSParameterAssert(torrent != nil);

    [self.fHashes addObject:torrent.hashString];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    [self.fLegacyDockTile setBadgeLabel:[NSString localizedStringWithFormat:@"%lu", static_cast<unsigned long>(self.fHashes.count)]];
    [self.fLegacyDockTile display];
#else
    [[NSApp dockTile] setBadgeLabel:[NSString localizedStringWithFormat:@"%lu", static_cast<unsigned long>(self.fHashes.count)]];
#endif
}

- (void)removeTorrent:(Torrent*)torrent
{
    if ([self.fHashes member:torrent.hashString])
    {
        [self.fHashes removeObject:torrent.hashString];
        if (self.fHashes.count > 0)
        {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
            [self.fLegacyDockTile
                setBadgeLabel:[NSString localizedStringWithFormat:@"%lu", static_cast<unsigned long>(self.fHashes.count)]];
            [self.fLegacyDockTile display];
#else
            [[NSApp dockTile] setBadgeLabel:[NSString localizedStringWithFormat:@"%lu", static_cast<unsigned long>(self.fHashes.count)]];
#endif
        }
        else
        {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
            [self.fLegacyDockTile setBadgeLabel:@""];
            [self.fLegacyDockTile display];
#else
            [[NSApp dockTile] setBadgeLabel:@""];
#endif
        }
    }
}

- (void)clearCompleted
{
    if (self.fHashes.count > 0)
    {
        [self.fHashes removeAllObjects];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
        [self.fLegacyDockTile setBadgeLabel:@""];
        [self.fLegacyDockTile display];
#else
        [[NSApp dockTile] setBadgeLabel:@""];
#endif
    }
}

@end
