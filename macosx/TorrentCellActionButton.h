// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "CocoaCompatibility.h"

#include <libtransmission/macos-version.h>

@class TorrentCell;

@interface TorrentCellActionButton : NSButton
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSTrackingArea* _fTrackingArea;
    NSImage* _fImage;
    NSImage* _fAlternativeImage;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7 || !TR_MACOS_DEPLOYMENT_BEFORE_10_8
    TorrentCell* __weak _torrentCell;
#endif
    NSUserDefaults* _fDefaults;
}
#endif
@end
