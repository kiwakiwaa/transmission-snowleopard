// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

@class BadgeView;

@interface LegacyDockTile : NSObject
{
  @private
    BadgeView* _fBadgeView;
    NSImage* _fOriginalIcon;
    NSString* _fBadgeLabel;
    BOOL _fShowsSpeedBadge;
    BOOL _fShowsDownloadSpeedBadge;
    BOOL _fShowsUploadSpeedBadge;
}

- (instancetype)initWithOriginalIcon:(NSImage*)originalIcon;
- (BOOL)setRatesWithDownload:(CGFloat)downloadRate upload:(CGFloat)uploadRate;
- (void)setBadgeLabel:(NSString*)badgeLabel;
- (NSImage*)renderedIcon;
- (void)display;
- (void)restoreOriginalIcon;

@end

#endif
