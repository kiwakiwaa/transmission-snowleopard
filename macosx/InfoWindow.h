// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

@interface InfoWindow : NSPanel

#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
@property(nonatomic) BOOL anchorsLiveResizeTopEdge;
@property(nonatomic) CGFloat liveResizeTopEdge;
#endif

@end
