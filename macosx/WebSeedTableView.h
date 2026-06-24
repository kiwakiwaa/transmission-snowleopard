// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

@interface WebSeedTableView : NSTableView<NSMenuItemValidation>

@property(nonatomic, weak) NSArray* webSeeds;

- (void)copy:(id)sender;

@end
