// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyTrackingArea.h"

#if TR_MACOS_SDK_BEFORE_10_5

#import "LegacyAssociatedObjects.h"

#import <objc/objc-class.h>
#import <objc/objc-runtime.h>

namespace
{

char const TrackingAreasKey = 0;
IMP OriginalWindowResetCursorRects;
BOOL UpdatingTrackingAreas;

BOOL TRTrackingAreaIsActive(NSTrackingArea* area, NSView* view)
{
    NSTrackingAreaOptions const activity = area.options & 0xF0;
    if (activity == NSTrackingActiveAlways)
    {
        return YES;
    }
    if (activity == NSTrackingActiveInKeyWindow)
    {
        return view.window.isKeyWindow;
    }
    if (activity == NSTrackingActiveInActiveApp)
    {
        return [NSApp isActive];
    }
    if (activity == NSTrackingActiveWhenFirstResponder)
    {
        return view.window.firstResponder == view;
    }
    return NO;
}

void TRUpdateTrackingAreasInView(NSView* view)
{
    [view updateTrackingAreas];

    NSEnumerator* enumerator = [[view subviews] objectEnumerator];
    NSView* subview = nil;
    while ((subview = [enumerator nextObject]) != nil)
    {
        TRUpdateTrackingAreasInView(subview);
    }
}

void TRWindowResetCursorRects(id self, SEL selector)
{
    ((void (*)(id, SEL))OriginalWindowResetCursorRects)(self, selector);
    if (UpdatingTrackingAreas)
    {
        return;
    }

    UpdatingTrackingAreas = YES;
    NSView* contentView = [(NSWindow*)self contentView];
    if (contentView != nil)
    {
        TRUpdateTrackingAreasInView(contentView);
    }
    UpdatingTrackingAreas = NO;
}

}

@interface NSTrackingArea (TRLegacyPrivate)
- (void)tr_installInView:(NSView*)view;
- (void)tr_uninstall;
- (void)tr_refresh;
- (void)tr_refreshForNotification:(NSNotification*)notification;
@end

@implementation NSTrackingArea

@synthesize rect = _rect;
@synthesize options = _options;
@synthesize owner = _owner;
@synthesize userInfo = _userInfo;

- (id)initWithRect:(NSRect)rect options:(NSTrackingAreaOptions)options owner:(id)owner userInfo:(NSDictionary*)userInfo
{
    if ((options & 0x07) == 0)
    {
        [NSException raise:NSInvalidArgumentException format:@"trackingArea options 0x%lx do not include a type", (unsigned long)options];
    }
    if ((options & 0xF0) == 0)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"trackingArea options 0x%lx do not specify when the tracking area is active", (unsigned long)options];
    }

    if ((self = [super init]))
    {
        _rect = rect;
        _options = options;
        _owner = owner;
        _userInfo = userInfo;
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(tr_refreshForNotification:) name:NSWindowDidBecomeKeyNotification object:nil];
        [center addObserver:self selector:@selector(tr_refreshForNotification:) name:NSWindowDidResignKeyNotification object:nil];
        [center addObserver:self selector:@selector(tr_refreshForNotification:) name:NSApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(tr_refreshForNotification:) name:NSApplicationDidResignActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self tr_uninstall];
}

- (void)mouseEntered:(NSEvent*)event
{
    [_owner mouseEntered:event];
}

- (void)mouseExited:(NSEvent*)event
{
    [_owner mouseExited:event];
}

- (void)_mouseEntered:(NSEvent*)event
{
    [self mouseEntered:event];
}

- (void)_mouseExited:(NSEvent*)event
{
    [self mouseExited:event];
}

- (void)tr_installInView:(NSView*)view
{
    [self tr_uninstall];
    _view = view;
    if (NSIsEmptyRect(_rect) || view.window == nil || !TRTrackingAreaIsActive(self, view))
    {
        return;
    }

    BOOL const assumeInside = (_options & NSTrackingAssumeInside) != 0;
    _trackingRectTag = [view addTrackingRect:_rect owner:self userData:(__bridge void*)_userInfo assumeInside:assumeInside];
}

- (void)tr_uninstall
{
    if (_trackingRectTag != 0 && _view != nil)
    {
        [_view removeTrackingRect:_trackingRectTag];
    }
    _trackingRectTag = 0;
}

- (void)tr_refresh
{
    if (_view != nil)
    {
        [self tr_installInView:_view];
    }
}

- (void)tr_refreshForNotification:(NSNotification*)notification
{
    (void)notification;
    [self tr_refresh];
}

@end

@implementation NSView (TRLegacyTrackingArea)

+ (void)load
{
    Method method = class_getInstanceMethod([NSWindow class], @selector(resetCursorRects));
    OriginalWindowResetCursorRects = method->method_imp;
    method->method_imp = (IMP)TRWindowResetCursorRects;
}

- (NSMutableArray*)tr_trackingAreasCreatingIfNeeded:(BOOL)create
{
    NSMutableArray* areas = TRLegacyGetAssociatedObject(self, &TrackingAreasKey);
    if (areas == nil && create)
    {
        areas = [NSMutableArray array];
        TRLegacySetAssociatedObject(self, &TrackingAreasKey, areas, TRLegacyAssociationRetainNonatomic);
    }
    return areas;
}

- (void)addTrackingArea:(NSTrackingArea*)trackingArea
{
    NSMutableArray* areas = [self tr_trackingAreasCreatingIfNeeded:YES];
    if (![areas containsObject:trackingArea])
    {
        [areas addObject:trackingArea];
    }
    [trackingArea tr_installInView:self];
}

- (void)removeTrackingArea:(NSTrackingArea*)trackingArea
{
    [trackingArea tr_uninstall];
    [[self tr_trackingAreasCreatingIfNeeded:NO] removeObject:trackingArea];
}

- (NSArray*)trackingAreas
{
    NSArray* areas = [[self tr_trackingAreasCreatingIfNeeded:NO] copy];
    return areas != nil ? areas : [NSArray array];
}

- (void)updateTrackingAreas
{
    NSEnumerator* enumerator = [[[self tr_trackingAreasCreatingIfNeeded:NO] copy] objectEnumerator];
    NSTrackingArea* area = nil;
    while ((area = [enumerator nextObject]) != nil)
    {
        [area tr_refresh];
    }
}

@end

#endif
