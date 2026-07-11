// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface WebSeedTableView : NSTableView<NSMenuItemValidation>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    NSArray* __weak _webSeeds;
}
#endif

@property(nonatomic, weak) NSArray* webSeeds;

- (void)copy:(id)sender;

@end
