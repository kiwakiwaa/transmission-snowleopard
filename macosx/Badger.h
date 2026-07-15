// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

@class LegacyDockTile;
@class Torrent;

@interface Badger : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSMutableSet* _fHashes;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    LegacyDockTile* _fLegacyDockTile;
#endif
}
#endif

- (void)updateBadgeWithDownload:(CGFloat)downloadRate upload:(CGFloat)uploadRate;
- (void)addCompletedTorrent:(Torrent*)torrent;
- (void)removeTorrent:(Torrent*)torrent;
- (void)clearCompleted;

@end
