// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyTitlebarAccessory.h"

#import <objc/runtime.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 101000
static char TRLegacyTitlebarAccessoryControllersKey;

static NSMutableArray* TRLegacyTitlebarAccessoryControllersForWindow(NSWindow* window, BOOL create)
{
    NSMutableArray* controllers = objc_getAssociatedObject(window, &TRLegacyTitlebarAccessoryControllersKey);
    if (controllers == nil && create)
    {
        controllers = [NSMutableArray array];
        objc_setAssociatedObject(window, &TRLegacyTitlebarAccessoryControllersKey, controllers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return controllers;
}

void TRLayoutLegacyTitlebarAccessoryWindow(NSWindow* window)
{
    NSView* contentView = window.contentView;
    if (contentView == nil)
    {
        return;
    }

    NSArray* controllers = TRLegacyTitlebarAccessoryControllersForWindow(window, NO);
    CGFloat accessoryHeight = 0.0;
    NSMutableArray* visibleControllers = [NSMutableArray arrayWithCapacity:controllers.count];
    for (NSTitlebarAccessoryViewController* controller in controllers)
    {
        NSView* view = controller.view;
        if (view != nil && !controller.isHidden)
        {
            [visibleControllers addObject:controller];
            accessoryHeight += NSHeight(view.frame) > 0.0 ? NSHeight(view.frame) : 24.0;
        }
        else
        {
            view.hidden = YES;
        }
    }

    NSRect bounds = contentView.bounds;
    CGFloat y = NSHeight(bounds);
    for (NSTitlebarAccessoryViewController* controller in visibleControllers)
    {
        NSView* view = controller.view;
        CGFloat height = NSHeight(view.frame) > 0.0 ? NSHeight(view.frame) : 24.0;
        y -= height;
        view.hidden = NO;
        view.frame = NSMakeRect(0.0, y, NSWidth(bounds), height);
        view.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    }

    CGFloat bottomHeight = 0.0;
    NSScrollView* scrollView = nil;
    for (NSView* subview in contentView.subviews)
    {
        BOOL isAccessory = NO;
        for (NSTitlebarAccessoryViewController* controller in controllers)
        {
            if (subview == controller.view)
            {
                isAccessory = YES;
                break;
            }
        }
        if (isAccessory)
        {
            continue;
        }

        if ([subview isKindOfClass:[NSScrollView class]])
        {
            scrollView = (NSScrollView*)subview;
        }
        else if (NSMinY(subview.frame) <= 1.0)
        {
            bottomHeight = MAX(bottomHeight, NSHeight(subview.frame));
        }
    }

    if (scrollView != nil)
    {
        scrollView.frame = NSMakeRect(0.0, bottomHeight, NSWidth(bounds), MAX(0.0, NSHeight(bounds) - bottomHeight - accessoryHeight));
        scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
}

@implementation NSTitlebarAccessoryViewController

@synthesize layoutAttribute = _layoutAttribute;
@synthesize hidden = _hidden;
@synthesize automaticallyAdjustsSize = _automaticallyAdjustsSize;

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
    self.view.hidden = hidden;
    TRLayoutLegacyTitlebarAccessoryWindow(self.view.window);
}

@end

@implementation NSWindow (TransmissionTitlebarAccessoryCompatibility)
- (void)addTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController*)controller
{
    NSView* view = controller.view;
    if (view == nil)
    {
        return;
    }

    NSMutableArray* controllers = TRLegacyTitlebarAccessoryControllersForWindow(self, YES);
    if (![controllers containsObject:controller])
    {
        [controllers addObject:controller];
    }

    if (view.superview != self.contentView)
    {
        [self.contentView addSubview:view];
    }

    TRLayoutLegacyTitlebarAccessoryWindow(self);
}
@end
#else
void TRLayoutLegacyTitlebarAccessoryWindow(NSWindow* window)
{
    (void)window;
}
#endif
