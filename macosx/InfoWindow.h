// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#ifndef TR_INSPECTOR_ANCHORED_LIVE_RESIZE
#define TR_INSPECTOR_ANCHORED_LIVE_RESIZE (TR_MACOS_DEPLOYMENT_BEFORE_10_14)
#endif

@interface InfoWindow : NSPanel
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
    BOOL _anchorsLiveResizeTopEdge;
    CGFloat _liveResizeTopEdge;
    BOOL _settingAnchoredFrame;
#endif
}
#endif

#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
@property(nonatomic) BOOL anchorsLiveResizeTopEdge;
@property(nonatomic) CGFloat liveResizeTopEdge;
#endif

@end
