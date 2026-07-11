// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@class Torrent;

@interface TrackerTableView : NSTableView<NSMenuItemValidation>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    Torrent* __weak _torrent;
    NSArray* __weak _trackers;
}
#endif

@property(nonatomic, weak) Torrent* torrent;
@property(nonatomic, weak) NSArray* trackers;

- (void)copy:(id)sender;
- (void)paste:(id)sender;

@end
