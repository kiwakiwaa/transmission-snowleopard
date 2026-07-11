// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "ButtonToolbarItem.h"

@interface ButtonToolbarItem ()

@property(nonatomic) BOOL fEnabled;
@property(nonatomic) BOOL fHasEnabledState;

@end

@implementation ButtonToolbarItem

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fEnabled = _fEnabled;
@synthesize fHasEnabledState = _fHasEnabledState;
#endif

- (void)applyStateToButton
{
    if (![self.view isKindOfClass:[NSButton class]])
    {
        return;
    }

    NSButton* button = (NSButton*)self.view;
    button.image = self.image;
    button.target = self.target;
    button.action = self.action;
    button.enabled = self.fHasEnabledState ? self.fEnabled : YES;
}

- (void)setView:(NSView*)view
{
    [super setView:view];
    [self applyStateToButton];
}

- (void)setImage:(NSImage*)image
{
    [super setImage:image];
    [self applyStateToButton];
}

- (void)setTarget:(id)target
{
    [super setTarget:target];
    [self applyStateToButton];
}

- (void)setAction:(SEL)action
{
    [super setAction:action];
    [self applyStateToButton];
}

- (void)setEnabled:(BOOL)enabled
{
    self.fEnabled = enabled;
    self.fHasEnabledState = YES;
    [super setEnabled:enabled];
    [self applyStateToButton];
}

- (void)validate
{
    self.enabled = [self.target validateToolbarItem:self];
}

- (NSMenuItem*)menuFormRepresentation
{
    NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:self.label action:self.action keyEquivalent:@""];
    menuItem.image = self.image;
    menuItem.target = self.target;
    menuItem.enabled = [self.target validateToolbarItem:self];

    return menuItem;
}

@end
