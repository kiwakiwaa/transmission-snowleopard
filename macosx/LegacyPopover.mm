// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyPopover.h"

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_7

#import <float.h>

@interface TRLegacyPopoverPanel : NSPanel
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    __unsafe_unretained TRLegacyPopover* popover;
}
#endif

@property(nonatomic, assign) TRLegacyPopover* popover;

@end

@interface TRLegacyPopoverFrameView : NSView
{
    NSView* fContentView;
    __unsafe_unretained TRLegacyPopover* fPopover;
    NSUInteger fAnchorEdge;
    NSPoint fAnchorPoint;
}

@property(nonatomic, retain) NSView* contentView;
@property(nonatomic, assign) TRLegacyPopover* popover;
@property(nonatomic) NSUInteger anchorEdge;
@property(nonatomic) NSPoint anchorPoint;

+ (NSRect)frameRectForContentRect:(NSRect)contentRect;
+ (NSRect)contentRectForFrameRect:(NSRect)frameRect;
- (NSBezierPath*)popoverPathForBounds:(NSRect)bounds;
- (CGFloat)adjustedAnchorPositionForBodyRect:(NSRect)bodyRect;

@end

@interface TRLegacyPopover () <NSWindowDelegate>
#if !TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSPopoverBehavior fBehavior;
    NSViewController* fContentViewController;
    __unsafe_unretained id<TRLegacyPopoverDelegate> fDelegate;
    TRLegacyPopoverPanel* fPanel;
    TRLegacyPopoverFrameView* fFrameView;
    NSView* fPositioningView;
    NSWindow* fPositioningWindow;
    NSRect fPositioningRect;
    NSRectEdge fPreferredEdge;
    NSUInteger fAnchorEdge;
    id fLocalEventMonitor;
    id fGlobalEventMonitor;
    BOOL fShown;
    BOOL fClosing;
    BOOL fAutomaticCloseRegistered;
    BOOL fGeometryChangeRegistered;
    BOOL fPositioningViewPostsFrameChangedNotifications;
    BOOL fPositioningViewPostsBoundsChangedNotifications;
    BOOL fPositioningViewGeometryNotificationsEnabled;
    BOOL fDeferredGeometryUpdateScheduled;
    BOOL fOrderFrontScheduled;
}
#endif
- (void)closeAskingDelegate:(BOOL)asksDelegate;
- (void)updatePanelContentAndFrame;
- (void)repositionPanel;
- (void)wireResponderChainForContentView:(NSView*)contentView;
- (NSRect)positioningRectInScreen;
- (NSRect)panelFrameForAnchorEdge:(NSUInteger)anchorEdge positioningRectInScreen:(NSRect)positioningRect panelSize:(NSSize)panelSize;
- (NSRect)panelFrame:(NSRect)panelFrame adjustedForVisibleFrame:(NSRect)visibleFrame anchorEdge:(NSUInteger)anchorEdge;
- (BOOL)panelFrame:(NSRect)panelFrame fitsInVisibleFrame:(NSRect)visibleFrame;
- (CGFloat)visibleAreaForPanelFrame:(NSRect)panelFrame visibleFrame:(NSRect)visibleFrame;
- (NSUInteger)anchorEdgeForPositioningRect:(NSRect)positioningRect panelSize:(NSSize)panelSize visibleFrame:(NSRect)visibleFrame panelFrame:(NSRect*)outPanelFrame;
- (NSPoint)anchorPointForPanelFrame:(NSRect)panelFrame positioningRectInScreen:(NSRect)positioningRect;
- (BOOL)anchorPointCanBeDrawn:(NSPoint)anchorPoint inPanelFrame:(NSRect)panelFrame;
- (void)postNotificationNamed:(NSString*)name selector:(SEL)selector;
- (void)registerPositioningViewGeometryChangeHandling;
- (void)unregisterPositioningViewGeometryChangeHandling;
- (void)schedulePositioningViewGeometryUpdate;
- (void)positioningViewGeometryDidChange:(NSNotification*)notification;
- (void)scheduleOrderFront;
- (void)orderPanelFrontIfNeeded;
- (void)cancelScheduledOrderFront;
- (void)registerAutomaticCloseHandlingIfNeeded;
- (void)unregisterAutomaticCloseHandling;
- (NSEvent*)handleLocalEvent:(NSEvent*)event;

@end

static NSString* const TRLegacyPopoverWillShowNotification = @"NSPopoverWillShowNotification";
static NSString* const TRLegacyPopoverDidShowNotification = @"NSPopoverDidShowNotification";
static NSString* const TRLegacyPopoverWillCloseNotification = @"NSPopoverWillCloseNotification";
static NSString* const TRLegacyPopoverDidCloseNotification = @"NSPopoverDidCloseNotification";
static NSString* const TRLegacyViewGeometryInWindowDidChangeNotification = @"NSViewGeometryInWindowDidChangeNotification";

static CGFloat const TRLegacyPopoverAnchorWidth = 22.0;
static CGFloat const TRLegacyPopoverAnchorHeight = 11.0;
static CGFloat const TRLegacyPopoverContentInset = 2.0;
static CGFloat const TRLegacyPopoverFrameOutset = TRLegacyPopoverAnchorHeight + TRLegacyPopoverContentInset;
static CGFloat const TRLegacyPopoverCornerRadius = 5.0;
static NSUInteger const TRLegacyPopoverNoAnchorEdge = (NSUInteger)-1;

static void TRLegacyPopoverPerformNoArgumentSelector(id object, SEL selector)
{
    void (*implementation)(id, SEL) = (void (*)(id, SEL))[object methodForSelector:selector];
    implementation(object, selector);
}

static NSMutableSet* TRLegacyActivePopovers()
{
    static NSMutableSet* activePopovers = nil;
    if (activePopovers == nil)
    {
        activePopovers = [[NSMutableSet alloc] init];
    }

    return activePopovers;
}

static BOOL TRLegacyPopoverSizeIsEmpty(NSSize size)
{
    return size.width <= 0.0 || size.height <= 0.0;
}

static CGFloat TRLegacyPopoverClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    return MIN(MAX(minimum, value), maximum);
}

static BOOL TRLegacyPopoverEventIsInsideRectInView(NSEvent* event, NSRect rect, NSView* view)
{
    if (event.window == nil || view == nil || event.window != view.window)
    {
        return NO;
    }

    NSPoint point = [view convertPoint:event.locationInWindow fromView:nil];
    return NSPointInRect(point, rect);
}

static NSUInteger TRLegacyPopoverAnchorEdgeForRectEdge(NSRectEdge edge, NSView* view)
{
    switch (edge)
    {
    case NSMinXEdge:
        return 2;

    case NSMaxXEdge:
        return 0;

    case NSMinYEdge:
        return [view isFlipped] ? 1 : 3;

    case NSMaxYEdge:
        return [view isFlipped] ? 3 : 1;
    }

    return edge;
}

@implementation TRLegacyPopoverPanel

@synthesize popover;

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (void)cancelOperation:(id)sender
{
    if (self.popover.behavior != NSPopoverBehaviorApplicationDefined)
    {
        [self.popover performClose:sender];
    }
    else
    {
        [super cancelOperation:sender];
    }
}

@end

@implementation TRLegacyPopoverFrameView

@synthesize contentView = fContentView;
@synthesize popover = fPopover;
@synthesize anchorEdge = fAnchorEdge;
@synthesize anchorPoint = fAnchorPoint;

+ (NSRect)frameRectForContentRect:(NSRect)contentRect
{
    return NSInsetRect(contentRect, -TRLegacyPopoverFrameOutset, -TRLegacyPopoverFrameOutset);
}

+ (NSRect)contentRectForFrameRect:(NSRect)frameRect
{
    return NSInsetRect(frameRect, TRLegacyPopoverFrameOutset, TRLegacyPopoverFrameOutset);
}

- (instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]) != nil)
    {
        fAnchorEdge = TRLegacyPopoverNoAnchorEdge;
        fAnchorPoint = NSMakePoint(NSMidX(frame), NSMidY(frame));
    }

    return self;
}

- (BOOL)isOpaque
{
    return NO;
}

- (void)setContentView:(NSView*)contentView
{
    if (fContentView == contentView)
    {
        return;
    }

    [fContentView removeFromSuperview];
    fContentView = contentView;

    if (fContentView != nil)
    {
        fContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:fContentView];
        [self layoutContentView];
    }
}

- (void)setAnchorEdge:(NSUInteger)anchorEdge
{
    if (fAnchorEdge != anchorEdge)
    {
        fAnchorEdge = anchorEdge;
        self.needsDisplay = YES;
    }
}

- (void)setAnchorPoint:(NSPoint)anchorPoint
{
    if (!NSEqualPoints(fAnchorPoint, anchorPoint))
    {
        fAnchorPoint = anchorPoint;
        self.needsDisplay = YES;
    }
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self layoutContentView];
    self.needsDisplay = YES;
}

- (void)layoutContentView
{
    fContentView.frame = [[self class] contentRectForFrameRect:self.bounds];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;

    [fPopover repositionPanel];

    [[NSColor clearColor] set];
    NSRectFillUsingOperation(self.bounds, NSCompositeCopy);

    NSBezierPath* path = [self popoverPathForBounds:self.bounds];
    if (path == nil)
    {
        return;
    }

    NSColor* fillColor = [NSColor colorWithCalibratedWhite:0.96 alpha:0.98];
    NSColor* strokeColor = [NSColor colorWithCalibratedWhite:0.48 alpha:0.72];

    [fillColor setFill];
    [path fill];

    [strokeColor setStroke];
    path.lineWidth = 1.0;
    [path setLineJoinStyle:NSRoundLineJoinStyle];
    [path stroke];
}

- (CGFloat)adjustedAnchorPositionForBodyRect:(NSRect)bodyRect
{
    CGFloat const halfAnchorWidth = TRLegacyPopoverAnchorWidth / 2.0;
    BOOL const horizontalAnchor = (fAnchorEdge & ~2U) == 1;
    CGFloat const proposedPosition = horizontalAnchor ? fAnchorPoint.x : fAnchorPoint.y;
    CGFloat const minimum = (horizontalAnchor ? NSMinX(bodyRect) : NSMinY(bodyRect)) + TRLegacyPopoverCornerRadius + halfAnchorWidth;
    CGFloat const maximum = (horizontalAnchor ? NSMaxX(bodyRect) : NSMaxY(bodyRect)) - TRLegacyPopoverCornerRadius - halfAnchorWidth;

    if (maximum < minimum)
    {
        return horizontalAnchor ? NSMidX(bodyRect) : NSMidY(bodyRect);
    }

    return TRLegacyPopoverClamp(proposedPosition, minimum, maximum);
}

- (NSBezierPath*)popoverPathForBounds:(NSRect)bounds
{
    NSRect bodyRect = NSInsetRect(bounds, TRLegacyPopoverAnchorHeight, TRLegacyPopoverAnchorHeight);
    if (NSWidth(bodyRect) <= 0.0 || NSHeight(bodyRect) <= 0.0)
    {
        return nil;
    }

    bodyRect = NSInsetRect(bodyRect, 0.5, 0.5);

    CGFloat const minimumX = NSMinX(bodyRect);
    CGFloat const maximumX = NSMaxX(bodyRect);
    CGFloat const minimumY = NSMinY(bodyRect);
    CGFloat const maximumY = NSMaxY(bodyRect);
    CGFloat const radius = TRLegacyPopoverCornerRadius;
    CGFloat const halfAnchorWidth = TRLegacyPopoverAnchorWidth / 2.0;
    CGFloat const anchorPosition = [self adjustedAnchorPositionForBodyRect:bodyRect];
    CGFloat const bottomTip = NSMinY(bounds) + 0.5;
    CGFloat const topTip = NSMaxY(bounds) - 0.5;
    CGFloat const leftTip = NSMinX(bounds) + 0.5;
    CGFloat const rightTip = NSMaxX(bounds) - 0.5;

    NSBezierPath* path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(minimumX + radius, minimumY)];

    if (fAnchorEdge == 1)
    {
        [path lineToPoint:NSMakePoint(anchorPosition - halfAnchorWidth, minimumY)];
        [path lineToPoint:NSMakePoint(anchorPosition, bottomTip)];
        [path lineToPoint:NSMakePoint(anchorPosition + halfAnchorWidth, minimumY)];
    }

    [path lineToPoint:NSMakePoint(maximumX - radius, minimumY)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(maximumX, minimumY) toPoint:NSMakePoint(maximumX, minimumY + radius) radius:radius];

    if (fAnchorEdge == 2)
    {
        [path lineToPoint:NSMakePoint(maximumX, anchorPosition - halfAnchorWidth)];
        [path lineToPoint:NSMakePoint(rightTip, anchorPosition)];
        [path lineToPoint:NSMakePoint(maximumX, anchorPosition + halfAnchorWidth)];
    }

    [path lineToPoint:NSMakePoint(maximumX, maximumY - radius)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(maximumX, maximumY) toPoint:NSMakePoint(maximumX - radius, maximumY) radius:radius];

    if (fAnchorEdge == 3)
    {
        [path lineToPoint:NSMakePoint(anchorPosition + halfAnchorWidth, maximumY)];
        [path lineToPoint:NSMakePoint(anchorPosition, topTip)];
        [path lineToPoint:NSMakePoint(anchorPosition - halfAnchorWidth, maximumY)];
    }

    [path lineToPoint:NSMakePoint(minimumX + radius, maximumY)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(minimumX, maximumY) toPoint:NSMakePoint(minimumX, maximumY - radius) radius:radius];

    if (fAnchorEdge == 0)
    {
        [path lineToPoint:NSMakePoint(minimumX, anchorPosition + halfAnchorWidth)];
        [path lineToPoint:NSMakePoint(leftTip, anchorPosition)];
        [path lineToPoint:NSMakePoint(minimumX, anchorPosition - halfAnchorWidth)];
    }

    [path lineToPoint:NSMakePoint(minimumX, minimumY + radius)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(minimumX, minimumY) toPoint:NSMakePoint(minimumX + radius, minimumY) radius:radius];
    [path closePath];

    return path;
}

@end

@implementation TRLegacyPopover

@synthesize behavior = fBehavior;
@synthesize contentViewController = fContentViewController;
@synthesize delegate = fDelegate;

+ (id)allocWithZone:(NSZone*)zone
{
    if (self == [TRLegacyPopover class])
    {
        Class realPopoverClass = NSClassFromString(@"NSPopover");
        if (realPopoverClass != Nil)
        {
            return [realPopoverClass allocWithZone:zone];
        }
    }

    return [super allocWithZone:zone];
}

- (instancetype)init
{
    if ((self = [super init]) != nil)
    {
        fBehavior = NSPopoverBehaviorApplicationDefined;
        fPreferredEdge = NSMaxYEdge;
        fAnchorEdge = TRLegacyPopoverNoAnchorEdge;
    }

    return self;
}

- (void)dealloc
{
    [self cancelScheduledOrderFront];
    [self unregisterPositioningViewGeometryChangeHandling];
    [self unregisterAutomaticCloseHandling];
    fPanel.delegate = nil;
    fPanel.popover = nil;
}

- (BOOL)isShown
{
    return fShown;
}

- (void)setBehavior:(NSPopoverBehavior)behavior
{
    if (fBehavior == behavior)
    {
        return;
    }

    if ((NSUInteger)behavior >= 3)
    {
        [NSException raise:NSInternalInconsistencyException format:@"Invalid value to %@", NSStringFromSelector(_cmd)];
    }

    fBehavior = behavior;

    if (fShown)
    {
        [self unregisterAutomaticCloseHandling];
        [self registerAutomaticCloseHandlingIfNeeded];
    }
}

- (void)setContentViewController:(NSViewController*)contentViewController
{
    if (fContentViewController == contentViewController)
    {
        return;
    }

    fContentViewController = contentViewController;

    if (fPanel != nil && fContentViewController.view != nil)
    {
        [self updatePanelContentAndFrame];
        [self repositionPanel];
    }
}

- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView*)positioningView preferredEdge:(NSRectEdge)preferredEdge
{
    if (positioningView == nil)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@: nil view provided. You must supply a view.", NSStringFromSelector(_cmd)];
    }

    NSWindow* positioningWindow = positioningView.window;
    if (positioningWindow == nil)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@: view has no window. You must supply a view in a window.", NSStringFromSelector(_cmd)];
    }

    NSView* contentView = self.contentViewController.view;
    if (contentView == nil)
    {
        [NSException raise:NSInternalInconsistencyException
                    format:@"The contentViewController (%@) or contentViewController.view is nil.", self.contentViewController];
    }

    if (NSIsEmptyRect(positioningRect))
    {
        positioningRect = positioningView.bounds;
    }

    if (![positioningWindow isVisible])
    {
        return;
    }

    if (NSIsEmptyRect(NSIntersectionRect(positioningRect, positioningView.visibleRect)))
    {
        return;
    }

    if (fClosing)
    {
        return;
    }

    BOOL const wasShown = fShown;
    NSWindow* previousPositioningWindow = fPositioningWindow;

    if (wasShown)
    {
        [self unregisterAutomaticCloseHandling];
        [self unregisterPositioningViewGeometryChangeHandling];
        [self cancelScheduledOrderFront];
    }

    fPositioningView = positioningView;
    fPositioningWindow = positioningWindow;
    fPositioningRect = positioningRect;
    fPreferredEdge = preferredEdge;
    fAnchorEdge = TRLegacyPopoverAnchorEdgeForRectEdge(preferredEdge, positioningView);

    [self updatePanelContentAndFrame];
    [self repositionPanel];

    if (wasShown)
    {
        if (previousPositioningWindow != nil && previousPositioningWindow != fPositioningWindow)
        {
            [previousPositioningWindow removeChildWindow:fPanel];
            [fPositioningWindow addChildWindow:fPanel ordered:NSWindowAbove];
        }

        [self registerPositioningViewGeometryChangeHandling];
        [self registerAutomaticCloseHandlingIfNeeded];
        return;
    }

    [self postNotificationNamed:TRLegacyPopoverWillShowNotification selector:@selector(popoverWillShow:)];

    fShown = YES;
    [TRLegacyActivePopovers() addObject:self];

    [self registerPositioningViewGeometryChangeHandling];
    [self scheduleOrderFront];

    [self postNotificationNamed:TRLegacyPopoverDidShowNotification selector:@selector(popoverDidShow:)];
    [self registerAutomaticCloseHandlingIfNeeded];
}

- (void)close
{
    [self closeAskingDelegate:NO];
}

- (void)performClose:(id)sender
{
    (void)sender;
    [self closeAskingDelegate:YES];
}

- (void)closeAskingDelegate:(BOOL)asksDelegate
{
    if ((!fShown && fPanel == nil) || fClosing)
    {
        return;
    }

    if (asksDelegate && [(id)fDelegate respondsToSelector:@selector(popoverShouldClose:)] && ![fDelegate popoverShouldClose:self])
    {
        return;
    }

    TRLegacyPopover* keepAlive = self;
    fClosing = YES;

    [self unregisterAutomaticCloseHandling];
    [self unregisterPositioningViewGeometryChangeHandling];
    [self cancelScheduledOrderFront];
    [self postNotificationNamed:TRLegacyPopoverWillCloseNotification selector:@selector(popoverWillClose:)];

    if (fPositioningWindow != nil && fPanel != nil)
    {
        [fPositioningWindow removeChildWindow:fPanel];
    }

    [fPanel orderOut:nil];
    fShown = NO;

    [self postNotificationNamed:TRLegacyPopoverDidCloseNotification selector:@selector(popoverDidClose:)];

    fPanel.delegate = nil;
    fPanel.popover = nil;
    fPanel = nil;
    fFrameView = nil;
    fPositioningView = nil;
    fPositioningWindow = nil;
    fPositioningRect = NSZeroRect;
    fAnchorEdge = TRLegacyPopoverNoAnchorEdge;
    fClosing = NO;

    [TRLegacyActivePopovers() removeObject:self];
    (void)keepAlive;
}

- (void)updatePanelContentAndFrame
{
    NSView* contentView = self.contentViewController.view;
    NSSize contentSize = contentView.frame.size;
    if (TRLegacyPopoverSizeIsEmpty(contentSize))
    {
        contentSize = NSMakeSize(250.0, 250.0);
    }

    NSRect contentRect = NSMakeRect(0.0, 0.0, contentSize.width, contentSize.height);
    NSRect frameRect = [TRLegacyPopoverFrameView frameRectForContentRect:contentRect];
    frameRect.origin = NSZeroPoint;

    if (fPanel == nil)
    {
        fPanel = [[TRLegacyPopoverPanel alloc] initWithContentRect:frameRect
                                                         styleMask:NSBorderlessWindowMask
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO];
        fPanel.popover = self;
        fPanel.delegate = self;
        fPanel.releasedWhenClosed = YES;
        fPanel.hidesOnDeactivate = NO;
        fPanel.floatingPanel = NO;
        fPanel.hasShadow = YES;
        fPanel.opaque = NO;
        fPanel.backgroundColor = NSColor.clearColor;
        fPanel.becomesKeyOnlyIfNeeded = YES;
        fPanel.title = @"";
        [fPanel setExcludedFromWindowsMenu:YES];

        fFrameView = [[TRLegacyPopoverFrameView alloc] initWithFrame:frameRect];
        fFrameView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        fFrameView.popover = self;
        fPanel.contentView = fFrameView;
    }

    fFrameView.frame = frameRect;
    fFrameView.anchorEdge = fAnchorEdge;
    fFrameView.contentView = contentView;
    [fPanel setContentSize:frameRect.size];
    [self wireResponderChainForContentView:contentView];
}

- (void)repositionPanel
{
    if (fPanel == nil || fPositioningView == nil || fPositioningWindow == nil)
    {
        return;
    }

    NSRect positioningRect = [self positioningRectInScreen];
    NSSize panelSize = fPanel.frame.size;
    NSScreen* screen = fPositioningWindow.screen ?: NSScreen.mainScreen;
    NSRect visibleFrame = screen.visibleFrame;
    NSRect panelFrame = NSZeroRect;

    NSUInteger anchorEdge = TRLegacyPopoverNoAnchorEdge;
    if (NSIsEmptyRect(positioningRect))
    {
        panelFrame = fPanel.frame;
        CGFloat const maxX = MAX(NSMinX(visibleFrame), NSMaxX(visibleFrame) - panelSize.width);
        CGFloat const maxY = MAX(NSMinY(visibleFrame), NSMaxY(visibleFrame) - panelSize.height);
        panelFrame.origin.x = TRLegacyPopoverClamp(NSMinX(panelFrame), NSMinX(visibleFrame), maxX);
        panelFrame.origin.y = TRLegacyPopoverClamp(NSMinY(panelFrame), NSMinY(visibleFrame), maxY);
    }
    else
    {
        anchorEdge = [self anchorEdgeForPositioningRect:positioningRect
                                             panelSize:panelSize
                                          visibleFrame:visibleFrame
                                            panelFrame:&panelFrame];
    }

    fAnchorEdge = anchorEdge;
    NSPoint anchorPoint = [self anchorPointForPanelFrame:panelFrame positioningRectInScreen:positioningRect];
    if (fAnchorEdge != TRLegacyPopoverNoAnchorEdge && ![self anchorPointCanBeDrawn:anchorPoint inPanelFrame:panelFrame])
    {
        fAnchorEdge = TRLegacyPopoverNoAnchorEdge;
        anchorPoint = NSMakePoint(DBL_MAX, DBL_MAX);
    }

    fFrameView.anchorEdge = fAnchorEdge;
    fFrameView.anchorPoint = anchorPoint;

    [fPanel setFrameOrigin:panelFrame.origin];
    [fPanel invalidateShadow];
}

- (void)wireResponderChainForContentView:(NSView*)contentView
{
    [contentView setNextResponder:self.contentViewController];
    [self.contentViewController setNextResponder:self];
    [self setNextResponder:fPanel];
}

- (NSRect)positioningRectInScreen
{
    if (fPositioningView == nil || fPositioningWindow == nil)
    {
        return NSZeroRect;
    }

    NSRect visiblePositioningRect = NSIntersectionRect(fPositioningRect, fPositioningView.visibleRect);
    if (NSIsEmptyRect(visiblePositioningRect))
    {
        return NSZeroRect;
    }

    NSRect positioningRectInWindow = [fPositioningView convertRect:visiblePositioningRect toView:nil];
    NSPoint positioningOrigin = [fPositioningWindow convertBaseToScreen:positioningRectInWindow.origin];
    NSRect positioningRect = NSMakeRect(positioningOrigin.x, positioningOrigin.y, NSWidth(positioningRectInWindow), NSHeight(positioningRectInWindow));

    if (fPositioningWindow.screen != nil)
    {
        positioningRect = NSIntersectionRect(positioningRect, fPositioningWindow.screen.frame);
    }

    return positioningRect;
}

- (NSRect)panelFrameForAnchorEdge:(NSUInteger)anchorEdge positioningRectInScreen:(NSRect)positioningRect panelSize:(NSSize)panelSize
{
    NSPoint origin = NSZeroPoint;

    switch (anchorEdge)
    {
    case 0:
        origin.x = NSMaxX(positioningRect);
        origin.y = floor(NSMidY(positioningRect) - panelSize.height / 2.0);
        break;

    case 1:
        origin.x = floor(NSMidX(positioningRect) - panelSize.width / 2.0);
        origin.y = NSMaxY(positioningRect);
        break;

    case 2:
        origin.x = NSMinX(positioningRect) - panelSize.width;
        origin.y = floor(NSMidY(positioningRect) - panelSize.height / 2.0);
        break;

    case 3:
        origin.x = floor(NSMidX(positioningRect) - panelSize.width / 2.0);
        origin.y = NSMinY(positioningRect) - panelSize.height;
        break;

    default:
        origin.x = floor(NSMidX(positioningRect) - panelSize.width / 2.0);
        origin.y = NSMaxY(positioningRect);
        break;
    }

    return NSMakeRect(origin.x, origin.y, panelSize.width, panelSize.height);
}

- (NSRect)panelFrame:(NSRect)panelFrame adjustedForVisibleFrame:(NSRect)visibleFrame anchorEdge:(NSUInteger)anchorEdge
{
    CGFloat const maxX = MAX(NSMinX(visibleFrame), NSMaxX(visibleFrame) - NSWidth(panelFrame));
    CGFloat const maxY = MAX(NSMinY(visibleFrame), NSMaxY(visibleFrame) - NSHeight(panelFrame));

    if ((anchorEdge & ~2U) == 1)
    {
        panelFrame.origin.x = TRLegacyPopoverClamp(NSMinX(panelFrame), NSMinX(visibleFrame), maxX);
    }
    else
    {
        panelFrame.origin.y = TRLegacyPopoverClamp(NSMinY(panelFrame), NSMinY(visibleFrame), maxY);
    }

    return panelFrame;
}

- (BOOL)panelFrame:(NSRect)panelFrame fitsInVisibleFrame:(NSRect)visibleFrame
{
    return NSMinX(panelFrame) >= NSMinX(visibleFrame) && NSMaxX(panelFrame) <= NSMaxX(visibleFrame) &&
        NSMinY(panelFrame) >= NSMinY(visibleFrame) && NSMaxY(panelFrame) <= NSMaxY(visibleFrame);
}

- (CGFloat)visibleAreaForPanelFrame:(NSRect)panelFrame visibleFrame:(NSRect)visibleFrame
{
    NSRect intersection = NSIntersectionRect(panelFrame, visibleFrame);
    if (NSIsEmptyRect(intersection))
    {
        return 0.0;
    }

    return NSWidth(intersection) * NSHeight(intersection);
}

- (NSUInteger)anchorEdgeForPositioningRect:(NSRect)positioningRect panelSize:(NSSize)panelSize visibleFrame:(NSRect)visibleFrame panelFrame:(NSRect*)outPanelFrame
{
    NSUInteger const preferredEdge = fAnchorEdge == TRLegacyPopoverNoAnchorEdge ? 1 : fAnchorEdge;
    NSUInteger const candidateEdges[] = {
        preferredEdge,
        (preferredEdge + 2) & 3,
        (NSUInteger)((preferredEdge & 1) == 0 ? 3 : 0),
        (NSUInteger)((preferredEdge & 1) == 0 ? 1 : 2),
    };
    NSUInteger selectedEdge = preferredEdge;
    NSRect selectedFrame = NSZeroRect;
    CGFloat bestArea = -1.0;

    for (NSUInteger i = 0; i < sizeof(candidateEdges) / sizeof(candidateEdges[0]); ++i)
    {
        NSUInteger const candidateEdge = candidateEdges[i];
        NSRect candidateFrame = [self panelFrameForAnchorEdge:candidateEdge positioningRectInScreen:positioningRect panelSize:panelSize];
        candidateFrame = [self panelFrame:candidateFrame adjustedForVisibleFrame:visibleFrame anchorEdge:candidateEdge];

        if ([self panelFrame:candidateFrame fitsInVisibleFrame:visibleFrame])
        {
            *outPanelFrame = candidateFrame;
            return candidateEdge;
        }

        CGFloat const visibleArea = [self visibleAreaForPanelFrame:candidateFrame visibleFrame:visibleFrame];
        if (visibleArea > bestArea)
        {
            bestArea = visibleArea;
            selectedEdge = candidateEdge;
            selectedFrame = candidateFrame;
        }
    }

    CGFloat const maxX = MAX(NSMinX(visibleFrame), NSMaxX(visibleFrame) - NSWidth(selectedFrame));
    CGFloat const maxY = MAX(NSMinY(visibleFrame), NSMaxY(visibleFrame) - NSHeight(selectedFrame));

    if (bestArea <= 0.0 || ![self panelFrame:selectedFrame fitsInVisibleFrame:visibleFrame])
    {
        selectedFrame.origin.x = NSMinX(visibleFrame) + floor((NSWidth(visibleFrame) - NSWidth(selectedFrame)) * 0.5);
        selectedFrame.origin.y = NSMinY(visibleFrame) + floor((NSHeight(visibleFrame) - NSHeight(selectedFrame)) * 0.75);
        selectedFrame.origin.x = TRLegacyPopoverClamp(NSMinX(selectedFrame), NSMinX(visibleFrame), maxX);
        selectedFrame.origin.y = TRLegacyPopoverClamp(NSMinY(selectedFrame), NSMinY(visibleFrame), maxY);
        *outPanelFrame = selectedFrame;
        return TRLegacyPopoverNoAnchorEdge;
    }

    selectedFrame.origin.x = TRLegacyPopoverClamp(NSMinX(selectedFrame), NSMinX(visibleFrame), maxX);
    selectedFrame.origin.y = TRLegacyPopoverClamp(NSMinY(selectedFrame), NSMinY(visibleFrame), maxY);
    *outPanelFrame = selectedFrame;

    return selectedEdge;
}

- (NSPoint)anchorPointForPanelFrame:(NSRect)panelFrame positioningRectInScreen:(NSRect)positioningRect
{
    if (NSIsEmptyRect(positioningRect))
    {
        return NSMakePoint(DBL_MAX, DBL_MAX);
    }

    NSPoint anchorPoint = NSZeroPoint;

    switch (fAnchorEdge)
    {
    case 0:
        anchorPoint.x = 0.0;
        anchorPoint.y = (MIN(NSMaxY(panelFrame), NSMaxY(positioningRect)) + MAX(NSMinY(panelFrame), NSMinY(positioningRect))) * 0.5 - NSMinY(panelFrame);
        break;

    case 1:
        anchorPoint.x = (MIN(NSMaxX(panelFrame), NSMaxX(positioningRect)) + MAX(NSMinX(panelFrame), NSMinX(positioningRect))) * 0.5 - NSMinX(panelFrame);
        anchorPoint.y = 0.0;
        break;

    case 2:
        anchorPoint.x = NSWidth(panelFrame) - 1.0;
        anchorPoint.y = (MIN(NSMaxY(panelFrame), NSMaxY(positioningRect)) + MAX(NSMinY(panelFrame), NSMinY(positioningRect))) * 0.5 - NSMinY(panelFrame);
        break;

    case 3:
        anchorPoint.x = (MIN(NSMaxX(panelFrame), NSMaxX(positioningRect)) + MAX(NSMinX(panelFrame), NSMinX(positioningRect))) * 0.5 - NSMinX(panelFrame);
        anchorPoint.y = NSHeight(panelFrame) - 1.0;
        break;

    default:
        anchorPoint = NSZeroPoint;
        break;
    }

    return anchorPoint;
}

- (BOOL)anchorPointCanBeDrawn:(NSPoint)anchorPoint inPanelFrame:(NSRect)panelFrame
{
    if (anchorPoint.x > DBL_MAX / 2.0 || anchorPoint.y > DBL_MAX / 2.0)
    {
        return NO;
    }

    NSRect bodyRect = NSMakeRect(TRLegacyPopoverAnchorHeight + 0.5,
        TRLegacyPopoverAnchorHeight + 0.5,
        NSWidth(panelFrame) - TRLegacyPopoverAnchorHeight * 2.0 - 1.0,
        NSHeight(panelFrame) - TRLegacyPopoverAnchorHeight * 2.0 - 1.0);
    CGFloat const halfAnchorWidth = TRLegacyPopoverAnchorWidth / 2.0;

    if ((fAnchorEdge & ~2U) == 1)
    {
        CGFloat const minimum = NSMinX(bodyRect) + TRLegacyPopoverCornerRadius + halfAnchorWidth;
        CGFloat const maximum = NSMaxX(bodyRect) - TRLegacyPopoverCornerRadius - halfAnchorWidth;
        return anchorPoint.x >= minimum && anchorPoint.x <= maximum;
    }

    CGFloat const minimum = NSMinY(bodyRect) + TRLegacyPopoverCornerRadius + halfAnchorWidth;
    CGFloat const maximum = NSMaxY(bodyRect) - TRLegacyPopoverCornerRadius - halfAnchorWidth;
    return anchorPoint.y >= minimum && anchorPoint.y <= maximum;
}

- (void)registerPositioningViewGeometryChangeHandling
{
    if (fGeometryChangeRegistered || fPositioningView == nil || !fShown)
    {
        return;
    }

    fPositioningViewPostsFrameChangedNotifications = fPositioningView.postsFrameChangedNotifications;
    fPositioningViewPostsBoundsChangedNotifications = fPositioningView.postsBoundsChangedNotifications;
    fPositioningView.postsFrameChangedNotifications = YES;
    fPositioningView.postsBoundsChangedNotifications = YES;

    SEL const enableGeometrySelector = NSSelectorFromString(@"enableGeometryInWindowDidChangeNotification");
    if ([fPositioningView respondsToSelector:enableGeometrySelector])
    {
        TRLegacyPopoverPerformNoArgumentSelector(fPositioningView, enableGeometrySelector);
        fPositioningViewGeometryNotificationsEnabled = YES;
    }

    NSNotificationCenter* notificationCenter = NSNotificationCenter.defaultCenter;
    [notificationCenter addObserver:self
                           selector:@selector(positioningViewGeometryDidChange:)
                               name:NSViewFrameDidChangeNotification
                             object:fPositioningView];
    [notificationCenter addObserver:self
                           selector:@selector(positioningViewGeometryDidChange:)
                               name:NSViewBoundsDidChangeNotification
                             object:fPositioningView];
    [notificationCenter addObserver:self
                           selector:@selector(positioningViewGeometryDidChange:)
                               name:TRLegacyViewGeometryInWindowDidChangeNotification
                             object:fPositioningView];

    fGeometryChangeRegistered = YES;
    [self schedulePositioningViewGeometryUpdate];
}

- (void)unregisterPositioningViewGeometryChangeHandling
{
    if (!fGeometryChangeRegistered)
    {
        return;
    }

    NSNotificationCenter* notificationCenter = NSNotificationCenter.defaultCenter;
    [notificationCenter removeObserver:self name:NSViewFrameDidChangeNotification object:fPositioningView];
    [notificationCenter removeObserver:self name:NSViewBoundsDidChangeNotification object:fPositioningView];
    [notificationCenter removeObserver:self name:TRLegacyViewGeometryInWindowDidChangeNotification object:fPositioningView];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(positioningViewGeometryDidChange:) object:nil];
    fDeferredGeometryUpdateScheduled = NO;

    if (fPositioningViewGeometryNotificationsEnabled)
    {
        SEL const disableGeometrySelector = NSSelectorFromString(@"disableGeometryInWindowDidChangeNotification");
        if ([fPositioningView respondsToSelector:disableGeometrySelector])
        {
            TRLegacyPopoverPerformNoArgumentSelector(fPositioningView, disableGeometrySelector);
        }

        fPositioningViewGeometryNotificationsEnabled = NO;
    }

    fPositioningView.postsFrameChangedNotifications = fPositioningViewPostsFrameChangedNotifications;
    fPositioningView.postsBoundsChangedNotifications = fPositioningViewPostsBoundsChangedNotifications;
    fGeometryChangeRegistered = NO;
}

- (void)schedulePositioningViewGeometryUpdate
{
    if (fDeferredGeometryUpdateScheduled)
    {
        return;
    }

    fDeferredGeometryUpdateScheduled = YES;
    [self performSelector:@selector(positioningViewGeometryDidChange:) withObject:nil afterDelay:0.0];
}

- (void)positioningViewGeometryDidChange:(NSNotification*)notification
{
    (void)notification;
    fDeferredGeometryUpdateScheduled = NO;

    if (fShown)
    {
        [self repositionPanel];
    }
}

- (void)scheduleOrderFront
{
    if (fOrderFrontScheduled)
    {
        return;
    }

    fOrderFrontScheduled = YES;
    [self performSelector:@selector(orderPanelFrontIfNeeded) withObject:nil afterDelay:0.0];
}

- (void)orderPanelFrontIfNeeded
{
    fOrderFrontScheduled = NO;

    if (!fShown || fClosing || fPanel == nil)
    {
        return;
    }

    [self repositionPanel];
    if (![[fPositioningWindow childWindows] containsObject:fPanel])
    {
        [fPositioningWindow addChildWindow:fPanel ordered:NSWindowAbove];
    }

    [fPanel orderFront:nil];
}

- (void)cancelScheduledOrderFront
{
    if (!fOrderFrontScheduled)
    {
        return;
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(orderPanelFrontIfNeeded) object:nil];
    fOrderFrontScheduled = NO;
}

- (void)postNotificationNamed:(NSString*)name selector:(SEL)selector
{
    NSNotification* notification = [NSNotification notificationWithName:name object:self];

    if (selector == @selector(popoverWillShow:) && [(id)fDelegate respondsToSelector:@selector(popoverWillShow:)])
    {
        [fDelegate popoverWillShow:notification];
    }
    else if (selector == @selector(popoverDidShow:) && [(id)fDelegate respondsToSelector:@selector(popoverDidShow:)])
    {
        [fDelegate popoverDidShow:notification];
    }
    else if (selector == @selector(popoverWillClose:) && [(id)fDelegate respondsToSelector:@selector(popoverWillClose:)])
    {
        [fDelegate popoverWillClose:notification];
    }
    else if (selector == @selector(popoverDidClose:) && [(id)fDelegate respondsToSelector:@selector(popoverDidClose:)])
    {
        [fDelegate popoverDidClose:notification];
    }

    [NSNotificationCenter.defaultCenter postNotification:notification];
}

- (void)registerAutomaticCloseHandlingIfNeeded
{
    if (fAutomaticCloseRegistered || fBehavior == NSPopoverBehaviorApplicationDefined || !fShown)
    {
        return;
    }

    __unsafe_unretained TRLegacyPopover* popover = self;
    NSUInteger const mouseDownMask = NSLeftMouseDownMask | NSRightMouseDownMask | NSOtherMouseDownMask;
    fLocalEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mouseDownMask | NSKeyDownMask
                                                               handler:^NSEvent*(NSEvent* event) {
                                                                   return [popover handleLocalEvent:event];
                                                               }];
    fGlobalEventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mouseDownMask
                                                                 handler:^(NSEvent* event) {
                                                                     (void)event;
                                                                     [popover close];
                                                                 }];

    NSNotificationCenter* notificationCenter = NSNotificationCenter.defaultCenter;
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidResignActive:)
                               name:NSApplicationDidResignActiveNotification
                             object:NSApplication.sharedApplication];
    [notificationCenter addObserver:self
                           selector:@selector(positioningWindowDidResignKey:)
                               name:NSWindowDidResignKeyNotification
                             object:fPositioningWindow];
    [notificationCenter addObserver:self
                           selector:@selector(positioningWindowWillClose:)
                               name:NSWindowWillCloseNotification
                             object:fPositioningWindow];

    fAutomaticCloseRegistered = YES;
}

- (void)unregisterAutomaticCloseHandling
{
    if (fLocalEventMonitor != nil)
    {
        [NSEvent removeMonitor:fLocalEventMonitor];
        fLocalEventMonitor = nil;
    }

    if (fGlobalEventMonitor != nil)
    {
        [NSEvent removeMonitor:fGlobalEventMonitor];
        fGlobalEventMonitor = nil;
    }

    if (fAutomaticCloseRegistered)
    {
        NSNotificationCenter* notificationCenter = NSNotificationCenter.defaultCenter;
        [notificationCenter removeObserver:self name:NSApplicationDidResignActiveNotification object:NSApplication.sharedApplication];
        [notificationCenter removeObserver:self name:NSWindowDidResignKeyNotification object:fPositioningWindow];
        [notificationCenter removeObserver:self name:NSWindowWillCloseNotification object:fPositioningWindow];
        fAutomaticCloseRegistered = NO;
    }
}

- (NSEvent*)handleLocalEvent:(NSEvent*)event
{
    if (event.type == NSKeyDown)
    {
        NSString* characters = event.charactersIgnoringModifiers;
        BOOL const isCommandPeriod = (event.modifierFlags & NSCommandKeyMask) != 0 && [characters isEqualToString:@"."];
        if (event.keyCode == 53 || isCommandPeriod)
        {
            [self performClose:self];
            return nil;
        }

        return event;
    }

    if (event.window == fPanel)
    {
        return event;
    }

    if (TRLegacyPopoverEventIsInsideRectInView(event, fPositioningRect, fPositioningView))
    {
        return nil;
    }

    [self close];
    return event;
}

- (void)applicationDidResignActive:(NSNotification*)notification
{
    (void)notification;
    [self close];
}

- (void)positioningWindowDidResignKey:(NSNotification*)notification
{
    (void)notification;
    NSWindow* keyWindow = NSApplication.sharedApplication.keyWindow;
    if (keyWindow != fPanel)
    {
        [self close];
    }
}

- (void)positioningWindowWillClose:(NSNotification*)notification
{
    (void)notification;
    [self close];
}

- (void)windowDidResignKey:(NSNotification*)notification
{
    (void)notification;
    NSWindow* keyWindow = NSApplication.sharedApplication.keyWindow;
    if (keyWindow != fPositioningWindow)
    {
        [self close];
    }
}

- (void)windowWillClose:(NSNotification*)notification
{
    (void)notification;
    [self close];
}

@end

#endif
