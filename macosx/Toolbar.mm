// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "Toolbar.h"

@interface Toolbar ()
@property(nonatomic) BOOL isRunningCustomizationPalette;
@end

@implementation Toolbar

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize isRunningCustomizationPalette = _isRunningCustomizationPalette;
#endif

- (void)setVisible:(BOOL)visible
{
    //we need to redraw the main window after each change
    //otherwise we get strange drawing issues, leading to a potential crash
    [NSNotificationCenter.defaultCenter postNotificationName:@"ToolbarDidChange" object:nil];

    super.visible = visible;
}

- (void)runCustomizationPalette:(nullable id)sender
{
    _isRunningCustomizationPalette = YES;
    [super runCustomizationPalette:sender];
    _isRunningCustomizationPalette = NO;
}

@end
