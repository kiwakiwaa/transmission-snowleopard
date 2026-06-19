// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "InfoWindowController.h"
#import "CocoaCompatibility.h"
#import "InfoViewController.h"
#import "InfoGeneralViewController.h"
#import "InfoActivityViewController.h"
#import "InfoTrackersViewController.h"
#import "InfoPeersViewController.h"
#import "InfoFileViewController.h"
#import "InfoOptionsViewController.h"
#import "InfoWindow.h"
#import "NSImageAdditions.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

typedef NSString* TabIdentifier NS_TYPED_EXTENSIBLE_ENUM;

static TabIdentifier const TabIdentifierInfo = @"Info";
static TabIdentifier const TabIdentifierActivity = @"Activity";
static TabIdentifier const TabIdentifierTracker = @"Tracker";
static TabIdentifier const TabIdentifierPeers = @"Peers";
static TabIdentifier const TabIdentifierFiles = @"Files";
static TabIdentifier const TabIdentifierOptions = @"Options";

static CGFloat const kTabMinHeight = 250;

static NSInteger const kInvalidTag = -99;

#define TR_INSPECTOR_ANCHORED_LIVE_RESIZE (TR_MACOS_DEPLOYMENT_BEFORE_10_10)

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
static void TRPrepareLegacyInspectorContentView(NSView* view, NSRect* viewRect, BOOL resizesVertically)
{
    view.translatesAutoresizingMaskIntoConstraints = YES;
    view.autoresizingMask = resizesVertically ? NSViewWidthSizable | NSViewHeightSizable : NSViewWidthSizable;
    viewRect->origin = NSZeroPoint;
}

static void TRClampLegacyResizableInspectorFrame(NSRect* windowRect, NSRect* viewRect)
{
    CGFloat const heightDeficit = kTabMinHeight - NSHeight(*viewRect);
    if (heightDeficit <= 0.0)
    {
        return;
    }

    viewRect->size.height = kTabMinHeight;
    windowRect->origin.y -= heightDeficit;
    windowRect->size.height += heightDeficit;
}
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@interface InfoActivityViewController (LegacyInspectorLayout)

- (CGFloat)legacyContentHeightForWidth:(CGFloat)width;
- (void)updateLegacyLayoutForWidth:(CGFloat)width height:(CGFloat)height;

@end

@interface InfoOptionsViewController (LegacyInspectorLayout)

- (CGFloat)legacyContentHeightForWidth:(CGFloat)width;
- (void)updateLegacyLayoutForWidth:(CGFloat)width height:(CGFloat)height;

@end
#endif

typedef NS_ENUM(NSUInteger, TabTag) {
    TabTagGeneral = 0,
    TabTagActivity = 1,
    TabTagTrackers = 2,
    TabTagPeers = 3,
    TabTagFile = 4,
    TabTagOptions = 5
};

@interface InfoWindowController ()

@property(nonatomic, copy) NSArray* fTorrents;

@property(nonatomic) CGFloat fMinWindowWidth;
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
// 10.8/10.9 can re-anchor programmatic height changes during edge drags.
// Keep the mouse-down top edge so auto-height panes grow from the bottom.
@property(nonatomic) CGFloat fLiveResizeTopEdge;
@property(nonatomic) BOOL fRestoringLiveResizeTopEdge;
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@property(nonatomic) BOOL fUpdatingWindowLayout;
@property(nonatomic) CGFloat fLegacyCurrentContentHeight;
@property(nonatomic) CGFloat fLegacyInspectorChromeHeight;
@property(nonatomic) NSMutableDictionary* fLegacyMinimumWidths;
#endif

@property(nonatomic) NSViewController<InfoViewController>* fViewController;
@property(nonatomic) NSInteger fCurrentTabTag;
@property(nonatomic) IBOutlet NSSegmentedControl* fTabs;

@property(nonatomic) InfoGeneralViewController* fGeneralViewController;
@property(nonatomic) InfoActivityViewController* fActivityViewController;
@property(nonatomic) InfoTrackersViewController* fTrackersViewController;
@property(nonatomic) InfoPeersViewController* fPeersViewController;
@property(nonatomic) InfoFileViewController* fFileViewController;
@property(nonatomic) InfoOptionsViewController* fOptionsViewController;

@property(nonatomic) IBOutlet NSImageView* fImageView;
@property(nonatomic) IBOutlet NSTextField* fNameField;
@property(nonatomic) IBOutlet NSTextField* fBasicInfoField;
@property(nonatomic) IBOutlet NSTextField* fNoneSelectedField;

#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
- (BOOL)isAutoHeightLayoutPane;
- (void)restoreLiveResizeTopEdgeDisplaying:(BOOL)display;
- (void)preserveLiveResizeTopEdgeIfNeeded;
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (CGFloat)legacyFixedContentHeightForWindowWidth:(CGFloat)width;
- (BOOL)isLegacyFixedHeightPane;
- (CGFloat)legacyMinimumWidthForView:(NSView*)view;
- (void)reflowLegacyStackViewIfNeeded;
- (void)syncLegacyFixedContentViewWithWindowWidth:(CGFloat)width height:(CGFloat)contentHeight;
- (void)syncLegacyFixedContentViewWithWindowWidth:(CGFloat)width;
- (void)resizeLegacyFixedHeightPaneAfterLiveResize;
- (void)syncLegacyInspectorContentViewFrameWithWindow;
#endif

@end

@implementation InfoWindowController

- (instancetype)init
{
    self = [super initWithWindowNibName:@"InfoWindow"];
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.fNoneSelectedField.stringValue = NSLocalizedString(@"No Torrents Selected", "Inspector -> selected torrents");

    //window location and size
    InfoWindow* window = (InfoWindow*)self.window;

    window.floatingPanel = NO;

    CGFloat const windowHeight = NSHeight(window.frame);
    self.fMinWindowWidth = window.minSize.width;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    self.fLegacyMinimumWidths = [NSMutableDictionary dictionary];
#endif

    [window setFrameAutosaveName:@"InspectorWindow"];
    [window setFrameUsingName:@"InspectorWindow"];

    NSRect windowRect = window.frame;
    windowRect.origin.y -= windowHeight - NSHeight(windowRect);
    windowRect.size.height = windowHeight;
    [window setFrame:windowRect display:NO];

    // Let inspector gain keyboard focus when clicked on non-interactive areas
    window.becomesKeyOnlyIfNeeded = NO;

    //disable green maximise window button
    //https://github.com/transmission/transmission/issues/3486
    [[window standardWindowButton:NSWindowZoomButton] setEnabled:NO];

    //set tab images and tooltips
    void (^setImageAndToolTipForSegment)(NSImage*, NSString*, NSInteger) = ^(NSImage* image, NSString* toolTip, NSInteger segment) {
        image.accessibilityDescription = toolTip;
        [self.fTabs setImage:image forSegment:segment];
        TRSetSegmentToolTip(self.fTabs, toolTip, segment);
    };
#if TR_MACOS_DEPLOYMENT_BEFORE_10_14
    setImageAndToolTipForSegment([NSImage imageNamed:@"InfoGeneral"], NSLocalizedString(@"General Info", "Inspector -> tab"), TabTagGeneral);
    setImageAndToolTipForSegment([NSImage imageNamed:@"InfoActivity"], NSLocalizedString(@"Activity", "Inspector -> tab"), TabTagActivity);
    setImageAndToolTipForSegment([NSImage imageNamed:@"InfoTracker"], NSLocalizedString(@"Trackers", "Inspector -> tab"), TabTagTrackers);
    setImageAndToolTipForSegment([NSImage imageNamed:@"InfoPeers"], NSLocalizedString(@"Peers", "Inspector -> tab"), TabTagPeers);
    setImageAndToolTipForSegment([NSImage imageNamed:@"InfoFiles"], NSLocalizedString(@"Files", "Inspector -> tab"), TabTagFile);
    setImageAndToolTipForSegment([NSImage imageNamed:@"InfoOptions"], NSLocalizedString(@"Options", "Inspector -> tab"), TabTagOptions);
#else
    setImageAndToolTipForSegment(TRImageForSystemSymbol(@"info.circle", nil), NSLocalizedString(@"General Info", "Inspector -> tab"), TabTagGeneral);
    setImageAndToolTipForSegment(TRImageForSystemSymbol(@"square.grid.3x3.fill.square", nil), NSLocalizedString(@"Activity", "Inspector -> tab"), TabTagActivity);
    setImageAndToolTipForSegment(
        TRImageForSystemSymbol(@"antenna.radiowaves.left.and.right", nil),
        NSLocalizedString(@"Trackers", "Inspector -> tab"),
        TabTagTrackers);
    setImageAndToolTipForSegment(TRImageForSystemSymbol(@"person.2", nil), NSLocalizedString(@"Peers", "Inspector -> tab"), TabTagPeers);
    setImageAndToolTipForSegment(TRImageForSystemSymbol(@"doc.on.doc", nil), NSLocalizedString(@"Files", "Inspector -> tab"), TabTagFile);
    setImageAndToolTipForSegment(TRImageForSystemSymbol(@"gearshape", nil), NSLocalizedString(@"Options", "Inspector -> tab"), TabTagOptions);
#endif

    //set selected tab
    self.fCurrentTabTag = kInvalidTag;
    NSString* identifier = [NSUserDefaults.standardUserDefaults stringForKey:@"InspectorSelected"];
    NSInteger tag;
    if ([identifier isEqualToString:TabIdentifierInfo])
    {
        tag = TabTagGeneral;
    }
    else if ([identifier isEqualToString:TabIdentifierActivity])
    {
        tag = TabTagActivity;
    }
    else if ([identifier isEqualToString:TabIdentifierTracker])
    {
        tag = TabTagTrackers;
    }
    else if ([identifier isEqualToString:TabIdentifierPeers])
    {
        tag = TabTagPeers;
    }
    else if ([identifier isEqualToString:TabIdentifierFiles])
    {
        tag = TabTagFile;
    }
    else if ([identifier isEqualToString:TabIdentifierOptions])
    {
        tag = TabTagOptions;
    }
    else //safety
    {
        [NSUserDefaults.standardUserDefaults setObject:TabIdentifierInfo forKey:@"InspectorSelected"];
        tag = TabTagGeneral;
    }

    self.fTabs.selectedSegment = tag;
    [self setTab:nil];

    //set blank inspector
    [self setInfoForTorrents:@[]];

    //allow for update notifications
    NSNotificationCenter* nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(resetInfoForTorrent:) name:@"ResetInspector" object:nil];
    [nc addObserver:self selector:@selector(updateInfoStats) name:@"UpdateStats" object:nil];
    [nc addObserver:self selector:@selector(updateOptions) name:@"UpdateOptions" object:nil];

    //add a custom window resize notification heer so we can disable it temporarily in settab:
    [nc addObserver:self selector:@selector(windowWasResized:) name:NSWindowDidResizeNotification object:self.window];
}

- (void)dealloc
{
    if ([_fViewController respondsToSelector:@selector(saveViewSize)])
    {
        [_fViewController saveViewSize];
    }
}

- (void)windowWasResized:(NSNotification*)notification
{
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
    if (self.fRestoringLiveResizeTopEdge)
    {
        return;
    }
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    if (self.fUpdatingWindowLayout)
    {
        return;
    }

    self.fUpdatingWindowLayout = YES;
    @try
    {
        if ([self isLegacyFixedHeightPane])
        {
            [self syncLegacyFixedContentViewWithWindowWidth:NSWidth(self.window.frame)];
        }
        else
        {
            [self syncLegacyInspectorContentViewFrameWithWindow];
        }

#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
        [self preserveLiveResizeTopEdgeIfNeeded];
#endif

    }
    @finally
    {
        self.fUpdatingWindowLayout = NO;
    }
#else
    if (self.fViewController == self.fOptionsViewController)
    {
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
        // windowWillResize: has already proposed the live height. keep this
        // layout sync from scheduling a second AppKit frame adjustment
        [self.fOptionsViewController checkWindowSizeAnimated:NO];
        [self preserveLiveResizeTopEdgeIfNeeded];
#else
        [self.fOptionsViewController checkWindowSize];
#endif
    }
    else if (self.fViewController == self.fActivityViewController)
    {
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
        // windowWillResize: has already proposed the live height; keep this
        // layout sync from scheduling a second AppKit frame adjustment.
        [self.fActivityViewController checkWindowSizeAnimated:NO];
        [self preserveLiveResizeTopEdgeIfNeeded];
#else
        [self.fActivityViewController checkWindowSize];
#endif
    }
#endif
}

#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
- (BOOL)isAutoHeightLayoutPane
{
    return self.fViewController == self.fActivityViewController || self.fViewController == self.fOptionsViewController;
}

- (void)preserveLiveResizeTopEdgeIfNeeded
{
    if (self.fLiveResizeTopEdge <= 0.0 || ![self isAutoHeightLayoutPane] || ![self.fViewController.view inLiveResize])
    {
        return;
    }

    [self restoreLiveResizeTopEdgeDisplaying:NO];
}

- (void)restoreLiveResizeTopEdgeDisplaying:(BOOL)display
{
    NSRect windowRect = self.window.frame;
    CGFloat const anchoredOriginY = self.fLiveResizeTopEdge - NSHeight(windowRect);
    if (ABS(NSMinY(windowRect) - anchoredOriginY) <= 0.5)
    {
        return;
    }

    windowRect.origin.y = anchoredOriginY;
    self.fRestoringLiveResizeTopEdge = YES;
    [self.window setFrame:windowRect display:display animate:NO];
    self.fRestoringLiveResizeTopEdge = NO;
}
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (CGFloat)legacyFixedContentHeightForWindowWidth:(CGFloat)width
{
    if (self.fViewController == self.fActivityViewController)
    {
        return [self.fActivityViewController legacyContentHeightForWidth:width];
    }
    else if (self.fViewController == self.fOptionsViewController)
    {
        return [self.fOptionsViewController legacyContentHeightForWidth:width];
    }

    return 0.0;
}

- (BOOL)isLegacyFixedHeightPane
{
    return self.fViewController == self.fActivityViewController || self.fViewController == self.fOptionsViewController;
}

- (CGFloat)legacyMinimumWidthForView:(NSView*)view
{
    NSNumber* key = [NSNumber numberWithInteger:self.fCurrentTabTag];
    NSNumber* minimumWidth = [self.fLegacyMinimumWidths objectForKey:key];
    if (minimumWidth == nil)
    {
        CGFloat width = NSWidth(view.frame);
        if (width <= 0.0)
        {
            width = self.fMinWindowWidth;
        }

        minimumWidth = [NSNumber numberWithDouble:width];
        [self.fLegacyMinimumWidths setObject:minimumWidth forKey:key];
    }

    return MAX(self.fMinWindowWidth, minimumWidth.doubleValue);
}

- (void)reflowLegacyStackViewIfNeeded
{
    if (self.fViewController == self.fActivityViewController)
    {
        [self.fActivityViewController checkLayout];
    }
    else if (self.fViewController == self.fOptionsViewController)
    {
        [self.fOptionsViewController checkLayout];
    }
}

- (void)syncLegacyFixedContentViewWithWindowWidth:(CGFloat)width
{
    CGFloat const preferredContentHeight = [self legacyFixedContentHeightForWindowWidth:width];
    if (preferredContentHeight <= 0.0)
    {
        return;
    }

    [self syncLegacyFixedContentViewWithWindowWidth:width height:preferredContentHeight];
}

- (void)syncLegacyFixedContentViewWithWindowWidth:(CGFloat)width height:(CGFloat)contentHeight
{
    if (contentHeight <= 0.0)
    {
        return;
    }

    if (self.fViewController == self.fActivityViewController)
    {
        [self.fActivityViewController updateLegacyLayoutForWidth:width height:contentHeight];
    }
    else if (self.fViewController == self.fOptionsViewController)
    {
        [self.fOptionsViewController updateLegacyLayoutForWidth:width height:contentHeight];
    }

    CGFloat const windowHeight = contentHeight + self.fLegacyInspectorChromeHeight;
    self.window.minSize = NSMakeSize(self.window.minSize.width, windowHeight);
    self.window.maxSize = NSMakeSize(FLT_MAX, windowHeight);
    self.fLegacyCurrentContentHeight = contentHeight;
}

- (void)windowWillStartLiveResize:(NSNotification*)notification
{
    if (notification.object == self.window && [self isLegacyFixedHeightPane])
    {
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
        self.fLiveResizeTopEdge = NSMaxY(self.window.frame);
        ((InfoWindow*)self.window).anchorsLiveResizeTopEdge = YES;
        ((InfoWindow*)self.window).liveResizeTopEdge = self.fLiveResizeTopEdge;
#endif
    }
}

- (void)resizeLegacyFixedHeightPaneAfterLiveResize
{
    CGFloat const contentHeight = [self legacyFixedContentHeightForWindowWidth:NSWidth(self.window.frame)];
    if (contentHeight <= 0.0)
    {
        return;
    }

    CGFloat const windowHeight = contentHeight + self.fLegacyInspectorChromeHeight;
    NSRect windowRect = self.window.frame;
    if (ABS(NSHeight(windowRect) - windowHeight) > 0.5)
    {
        windowRect.origin.y = NSMaxY(windowRect) - windowHeight;
        windowRect.size.height = windowHeight;
        [self.window setFrame:windowRect display:YES animate:NO];
    }

    [self syncLegacyFixedContentViewWithWindowWidth:NSWidth(windowRect)];
}

- (void)windowDidEndLiveResize:(NSNotification*)notification
{
    if (notification.object == self.window && [self isLegacyFixedHeightPane])
    {
        [self resizeLegacyFixedHeightPaneAfterLiveResize];
#if TR_INSPECTOR_ANCHORED_LIVE_RESIZE
        [self restoreLiveResizeTopEdgeDisplaying:YES];
        self.fLiveResizeTopEdge = 0.0;
        ((InfoWindow*)self.window).anchorsLiveResizeTopEdge = NO;
        ((InfoWindow*)self.window).liveResizeTopEdge = 0.0;
#endif
    }
}

- (void)syncLegacyInspectorContentViewFrameWithWindow
{
    if (!self.fViewController || !self.fViewController.view.superview || !self.window)
    {
        return;
    }

    BOOL const viewCanResizeVertically = [self.fViewController respondsToSelector:@selector(saveViewSize)];
    NSView* view = self.fViewController.view;
    NSRect viewRect = view.frame;
    TRPrepareLegacyInspectorContentView(view, &viewRect, viewCanResizeVertically);
    viewRect.size.width = NSWidth(self.window.frame);

    if (viewCanResizeVertically && self.fLegacyInspectorChromeHeight > 0.0)
    {
        viewRect.size.height = MAX(kTabMinHeight, NSHeight(self.window.frame) - self.fLegacyInspectorChromeHeight);
    }

    view.frame = viewRect;
    [self reflowLegacyStackViewIfNeeded];
    self.fLegacyCurrentContentHeight = NSHeight(viewRect);
}

- (NSSize)windowWillResize:(NSWindow*)sender toSize:(NSSize)frameSize
{
    if (!self.fUpdatingWindowLayout && sender == self.window && self.fViewController &&
        ![self.fViewController respondsToSelector:@selector(saveViewSize)])
    {
        CGFloat contentHeight = self.fLegacyCurrentContentHeight;
        CGFloat const fixedContentHeight = [self legacyFixedContentHeightForWindowWidth:frameSize.width];
        if (fixedContentHeight > 0.0)
        {
            contentHeight = fixedContentHeight;
            [self syncLegacyFixedContentViewWithWindowWidth:frameSize.width height:contentHeight];
        }
        CGFloat const windowHeight = contentHeight + self.fLegacyInspectorChromeHeight;
        frameSize.height = windowHeight > 0.0 ? windowHeight : NSHeight(sender.frame);
        if (fixedContentHeight > 0.0)
        {
            sender.minSize = NSMakeSize(sender.minSize.width, frameSize.height);
            sender.maxSize = NSMakeSize(FLT_MAX, frameSize.height);
        }
    }

    return frameSize;
}
#endif

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9 && TR_INSPECTOR_ANCHORED_LIVE_RESIZE
- (NSSize)windowWillResize:(NSWindow*)sender toSize:(NSSize)frameSize
{
    if (sender == self.window && [self isAutoHeightLayoutPane])
    {
        // Mavericks centers delegate-proposed height changes during side-edge
        // live resize; InfoWindow clamps AppKit's setFrame: before it is drawn.
        CGFloat contentHeight = 0.0;
        if (self.fViewController == self.fActivityViewController)
        {
            contentHeight = [self.fActivityViewController contentHeightForWindowWidth:frameSize.width];
        }
        else if (self.fViewController == self.fOptionsViewController)
        {
            contentHeight = [self.fOptionsViewController contentHeightForWindowWidth:frameSize.width];
        }

        CGFloat const chromeHeight = NSHeight(sender.frame) - NSHeight(self.fViewController.view.frame);
        if (contentHeight > 0.0 && chromeHeight > 0.0)
        {
            frameSize.height = contentHeight + chromeHeight;
            sender.minSize = NSMakeSize(sender.minSize.width, frameSize.height);
            sender.maxSize = NSMakeSize(FLT_MAX, frameSize.height);
        }
    }

    return frameSize;
}

- (void)windowWillStartLiveResize:(NSNotification*)notification
{
    if (notification.object == self.window && [self isAutoHeightLayoutPane])
    {
        self.fLiveResizeTopEdge = NSMaxY(self.window.frame);
        ((InfoWindow*)self.window).anchorsLiveResizeTopEdge = YES;
        ((InfoWindow*)self.window).liveResizeTopEdge = self.fLiveResizeTopEdge;
    }
}

- (void)windowDidEndLiveResize:(NSNotification*)notification
{
    if (notification.object == self.window && [self isAutoHeightLayoutPane])
    {
        [self restoreLiveResizeTopEdgeDisplaying:YES];
        self.fLiveResizeTopEdge = 0.0;
        ((InfoWindow*)self.window).anchorsLiveResizeTopEdge = NO;
        ((InfoWindow*)self.window).liveResizeTopEdge = 0.0;
    }
}
#endif

- (void)setInfoForTorrents:(NSArray*)torrents
{
    if ([self.fTorrents isEqualToArray:torrents])
    {
        return;
    }

    self.fTorrents = torrents;

    [self resetInfo];
}

- (void)removeTorrentsFromInfo:(NSArray*)torrents
{
    if (self.fTorrents.count == 0 || torrents.count == 0)
    {
        return;
    }

    NSMutableArray* remaining = [self.fTorrents mutableCopy];
    [remaining removeObjectsInArray:torrents];
    [self setInfoForTorrents:remaining];
}

- (NSRect)windowWillUseStandardFrame:(NSWindow*)window defaultFrame:(NSRect)defaultFrame
{
    NSRect windowRect = window.frame;
    windowRect.size.width = window.minSize.width;
    return windowRect;
}

- (void)windowWillClose:(NSNotification*)notification
{
    if (self.fCurrentTabTag == TabTagFile && ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]))
    {
        [[QLPreviewPanel sharedPreviewPanel] reloadData];
    }
}

- (void)setTab:(id)sender
{
    NSInteger const oldTabTag = self.fCurrentTabTag;
    self.fCurrentTabTag = self.fTabs.selectedSegment;
    if (self.fCurrentTabTag == oldTabTag)
    {
        return;
    }

    //remove window resize notification
    [NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowDidResizeNotification object:self.window];

    //take care of old view
    CGFloat oldHeight = 0;
    if (oldTabTag != kInvalidTag)
    {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        NSView* oldView = self.fViewController.view;
        [self syncLegacyInspectorContentViewFrameWithWindow];
#endif
        if ([self.fViewController respondsToSelector:@selector(saveViewSize)])
        {
            [self.fViewController saveViewSize];
        }

        if ([self.fViewController respondsToSelector:@selector(clearView)])
        {
            [self.fViewController clearView];
        }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        oldHeight = self.fLegacyCurrentContentHeight > 0.0 ? self.fLegacyCurrentContentHeight : NSHeight(oldView.frame);
#else
        NSView* oldView = self.fViewController.view;
        oldHeight = NSHeight(oldView.frame);
#endif

        //remove old view
        [oldView removeFromSuperview];
    }

    //set new tab item
    TabIdentifier identifier;
    switch (self.fCurrentTabTag)
    {
    case TabTagGeneral:
        if (!self.fGeneralViewController)
        {
            self.fGeneralViewController = [[InfoGeneralViewController alloc] init];
            [self.fGeneralViewController setInfoForTorrents:self.fTorrents];
        }

        self.fViewController = self.fGeneralViewController;
        identifier = TabIdentifierInfo;
        break;
    case TabTagActivity:
        if (!self.fActivityViewController)
        {
            self.fActivityViewController = [[InfoActivityViewController alloc] init];
            [self.fActivityViewController setInfoForTorrents:self.fTorrents];
        }

        self.fViewController = self.fActivityViewController;
        identifier = TabIdentifierActivity;
        break;
    case TabTagTrackers:
        if (!self.fTrackersViewController)
        {
            self.fTrackersViewController = [[InfoTrackersViewController alloc] init];
            [self.fTrackersViewController setInfoForTorrents:self.fTorrents];
        }

        self.fViewController = self.fTrackersViewController;
        identifier = TabIdentifierTracker;
        break;
    case TabTagPeers:
        if (!self.fPeersViewController)
        {
            self.fPeersViewController = [[InfoPeersViewController alloc] init];
            [self.fPeersViewController setInfoForTorrents:self.fTorrents];
        }

        self.fViewController = self.fPeersViewController;
        identifier = TabIdentifierPeers;
        break;
    case TabTagFile:
        if (!self.fFileViewController)
        {
            self.fFileViewController = [[InfoFileViewController alloc] init];
            [self.fFileViewController setInfoForTorrents:self.fTorrents];
        }

        self.fViewController = self.fFileViewController;
        identifier = TabIdentifierFiles;
        break;
    case TabTagOptions:
        if (!self.fOptionsViewController)
        {
            self.fOptionsViewController = [[InfoOptionsViewController alloc] init];
            [self.fOptionsViewController setInfoForTorrents:self.fTorrents];
        }

        self.fViewController = self.fOptionsViewController;
        identifier = TabIdentifierOptions;
        break;
    default:
        NSAssert1(NO, @"Unknown info tab selected: %ld", self.fCurrentTabTag);
        return;
    }

    [NSUserDefaults.standardUserDefaults setObject:identifier forKey:@"InspectorSelected"];

    NSWindow* window = self.window;

    window.title = [NSString
        stringWithFormat:@"%@ — %@", self.fViewController.title, NSLocalizedString(@"Torrent Inspector", "Inspector -> title")];

    NSView* view = self.fViewController.view;

    [self.fViewController updateInfo];

    NSRect windowRect = window.frame, viewRect = view.frame;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    CGFloat minWindowWidth = [self legacyMinimumWidthForView:view];
#else
    CGFloat minWindowWidth = MAX(self.fMinWindowWidth, view.fittingSize.width);
#endif
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    BOOL const viewCanResizeVertically = [self.fViewController respondsToSelector:@selector(saveViewSize)];

    TRPrepareLegacyInspectorContentView(view, &viewRect, viewCanResizeVertically);
    viewRect.size.width = NSWidth(windowRect);
    view.frame = viewRect;
#endif

    //special case for Activity and Options views
    if (self.fViewController == self.fActivityViewController)
    {
        [self.fActivityViewController setOldHeight:oldHeight];
        [self.fActivityViewController checkLayout];

        minWindowWidth = MAX(self.fMinWindowWidth, self.fActivityViewController.fTransferView.frame.size.width);
        viewRect = [self.fActivityViewController viewRect];
    }
    else if (self.fViewController == self.fOptionsViewController)
    {
        [self.fOptionsViewController setOldHeight:oldHeight];
        [self.fOptionsViewController checkLayout];

        minWindowWidth = MAX(self.fMinWindowWidth, self.fOptionsViewController.fPriorityView.frame.size.width);
        viewRect = [self.fOptionsViewController viewRect];
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    CGFloat viewHeightDifference = NSHeight(viewRect) - oldHeight;
#else
    CGFloat const viewHeightDifference = NSHeight(viewRect) - oldHeight;
#endif
    windowRect.origin.y -= viewHeightDifference;
    windowRect.size.height += viewHeightDifference;
    windowRect.size.width = MAX(NSWidth(windowRect), minWindowWidth);

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    if (self.fViewController == self.fActivityViewController || self.fViewController == self.fOptionsViewController)
    {
        viewRect.size.width = NSWidth(windowRect);
        view.frame = viewRect;
        [self reflowLegacyStackViewIfNeeded];
        viewRect = self.fViewController == self.fActivityViewController ? [self.fActivityViewController viewRect] :
                                                                          [self.fOptionsViewController viewRect];
        CGFloat const revisedViewHeightDifference = NSHeight(viewRect) - oldHeight;
        windowRect.origin.y -= revisedViewHeightDifference - viewHeightDifference;
        windowRect.size.height += revisedViewHeightDifference - viewHeightDifference;
    }
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    if (viewCanResizeVertically) //a little bit hacky, but avoids requiring an extra method
#else
    if ([self.fViewController respondsToSelector:@selector(saveViewSize)]) //a little bit hacky, but avoids requiring an extra method
#endif
    {
        if (window.screen)
        {
            CGFloat const screenHeight = NSHeight(window.screen.visibleFrame);
            if (NSHeight(windowRect) > screenHeight)
            {
                CGFloat const windowHeightDifference = screenHeight - NSHeight(windowRect);
                windowRect.origin.y -= windowHeightDifference;
                windowRect.size.height += windowHeightDifference;

                viewRect.size.height += windowHeightDifference;
            }
        }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        TRClampLegacyResizableInspectorFrame(&windowRect, &viewRect);
#endif
        window.minSize = NSMakeSize(minWindowWidth, NSHeight(windowRect) - NSHeight(viewRect) + kTabMinHeight);
        window.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    }
    else
    {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        window.minSize = NSMakeSize(minWindowWidth, NSHeight(windowRect));
        window.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
#else
        window.minSize = NSMakeSize(minWindowWidth, NSHeight(windowRect));
        window.maxSize = NSMakeSize(FLT_MAX, NSHeight(windowRect));
#endif
    }

    viewRect.size.width = NSWidth(windowRect);
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    TRPrepareLegacyInspectorContentView(view, &viewRect, viewCanResizeVertically);
    self.fLegacyInspectorChromeHeight = NSHeight(windowRect) - NSHeight(viewRect);
    self.fLegacyCurrentContentHeight = NSHeight(viewRect);
#endif
    view.frame = viewRect;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    BOOL const wasUpdatingWindowLayout = self.fUpdatingWindowLayout;
    self.fUpdatingWindowLayout = YES;
    @try
    {
        [window setFrame:windowRect display:YES animate:NO];
        view.frame = viewRect;
        view.hidden = NO;
        [window.contentView addSubview:view];
        [self syncLegacyInspectorContentViewFrameWithWindow];
        [window display];
    }
    @finally
    {
        self.fUpdatingWindowLayout = wasUpdatingWindowLayout;
    }
#else
    if (self.fViewController == self.fActivityViewController)
    {
        self.fActivityViewController.view.hidden = YES;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.fActivityViewController updateWindowLayout];
            self.fActivityViewController.view.hidden = NO;
        });
    }
    else if (self.fViewController == self.fOptionsViewController)
    {
        self.fOptionsViewController.view.hidden = YES;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.fOptionsViewController updateWindowLayout];
            self.fOptionsViewController.view.hidden = NO;
        });
    }
    else
    {
        [window setFrame:windowRect display:YES animate:oldTabTag != kInvalidTag];
    }

    [window.contentView addSubview:view];

    [window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[view]-0-|" options:0 metrics:nil
                                                                                 views:@{ @"view" : view }]];
    [window.contentView
        addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[tabs]-0-[view]-0-|" options:0 metrics:nil
                                                                 views:@{ @"tabs" : self.fTabs, @"view" : view }]];
#endif

    if ((self.fCurrentTabTag == TabTagFile || oldTabTag == TabTagFile) &&
        ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]))
    {
        [[QLPreviewPanel sharedPreviewPanel] reloadData];
    }

    //add window resize notification
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowWasResized:)
                                                   name:NSWindowDidResizeNotification
                                                 object:self.window];
    });
}

- (void)setNextTab
{
    NSInteger tag = self.fTabs.selectedSegment + 1;
    if (tag >= self.fTabs.segmentCount)
    {
        tag = 0;
    }

    self.fTabs.selectedSegment = tag;
    [self setTab:nil];
}

- (void)setPreviousTab
{
    NSInteger tag = self.fTabs.selectedSegment - 1;
    if (tag < 0)
    {
        tag = self.fTabs.segmentCount - 1;
    }

    self.fTabs.selectedSegment = tag;
    [self setTab:nil];
}

- (void)swipeWithEvent:(NSEvent*)event
{
    if (event.deltaX < 0.0)
    {
        [self setNextTab];
    }
    else if (event.deltaX > 0.0)
    {
        [self setPreviousTab];
    }
}

- (void)updateInfoStats
{
    [self.fViewController updateInfo];
}

- (void)updateOptions
{
    [self.fOptionsViewController updateOptions];
}

- (NSArray*)quickLookURLs
{
    return self.fFileViewController.quickLookURLs;
}

- (BOOL)canQuickLook
{
    if (self.fCurrentTabTag != TabTagFile || ![self.window isVisible])
    {
        return NO;
    }

    return self.fFileViewController.canQuickLook;
}

- (NSRect)quickLookSourceFrameForPreviewItem:(id<QLPreviewItem>)item
{
    return [self.fFileViewController quickLookSourceFrameForPreviewItem:item];
}

#pragma mark - Private

- (void)resetInfo
{
    NSUInteger const numberSelected = self.fTorrents.count;
    if (numberSelected != 1)
    {
        if (numberSelected > 0)
        {
            self.fImageView.image = [NSImage imageNamed:NSImageNameMultipleDocuments];

            self.fNameField.stringValue = [NSString
                localizedStringWithFormat:NSLocalizedString(@"%lu Torrents Selected", "Inspector -> selected torrents"), numberSelected];
            self.fNameField.hidden = NO;

            uint64_t size = 0;
            NSUInteger fileCount = 0, magnetCount = 0;
            for (Torrent* torrent in self.fTorrents)
            {
                size += torrent.size;
                fileCount += torrent.fileCount;
                if (torrent.magnet)
                {
                    ++magnetCount;
                }
            }

            NSMutableArray* fileStrings = [NSMutableArray arrayWithCapacity:2];
            if (fileCount > 0)
            {
                NSString* fileString;
                if (fileCount == 1)
                {
                    fileString = NSLocalizedString(@"1 file", "Inspector -> selected torrents");
                }
                else
                {
                    fileString = [NSString
                        localizedStringWithFormat:NSLocalizedString(@"%lu files", "Inspector -> selected torrents"), fileCount];
                }
                [fileStrings addObject:fileString];
            }
            if (magnetCount > 0)
            {
                NSString* magnetString;
                if (magnetCount == 1)
                {
                    magnetString = NSLocalizedString(@"1 magnetized transfer", "Inspector -> selected torrents");
                }
                else
                {
                    magnetString = [NSString
                        localizedStringWithFormat:NSLocalizedString(@"%lu magnetized transfers", "Inspector -> selected torrents"), magnetCount];
                }
                [fileStrings addObject:magnetString];
            }

            NSString* fileString = [fileStrings componentsJoinedByString:@" + "];

            if (magnetCount < numberSelected)
            {
                self.fBasicInfoField.stringValue = [NSString
                    stringWithFormat:@"%@, %@",
                                     fileString,
                                     [NSString stringWithFormat:NSLocalizedString(@"%@ total", "Inspector -> selected torrents"),
                                                                [NSString stringForFileSize:size]]];

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_8 && !TR_MACOS_SDK_BEFORE_10_8
                NSByteCountFormatter* formatter = [[NSByteCountFormatter alloc] init];
                formatter.allowedUnits = NSByteCountFormatterUseBytes;
                self.fBasicInfoField.toolTip = [formatter stringFromByteCount:size];
#else
                self.fBasicInfoField.toolTip = [NSString stringWithFormat:@"%llu bytes", static_cast<unsigned long long>(size)];
#endif
            }
            else
            {
                self.fBasicInfoField.stringValue = fileString;
                self.fBasicInfoField.toolTip = nil;
            }
            self.fBasicInfoField.hidden = NO;

            self.fNoneSelectedField.hidden = YES;
        }
        else
        {
            self.fImageView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
            self.fNoneSelectedField.hidden = NO;

            self.fNameField.hidden = YES;
            self.fBasicInfoField.hidden = YES;
        }

        self.fNameField.toolTip = nil;
    }
    else
    {
        Torrent* torrent = self.fTorrents[0];

        self.fImageView.image = torrent.icon;

        NSString* name = torrent.name;
        self.fNameField.stringValue = name;
        self.fNameField.toolTip = name;
        self.fNameField.hidden = NO;

        if (!torrent.magnet)
        {
            NSString* basicString = [NSString stringForFileSize:torrent.size];
            if (torrent.folder)
            {
                NSString* fileString;
                NSUInteger const fileCount = torrent.fileCount;
                if (fileCount == 1)
                {
                    fileString = NSLocalizedString(@"1 file", "Inspector -> selected torrents");
                }
                else
                {
                    fileString = [NSString
                        localizedStringWithFormat:NSLocalizedString(@"%lu files", "Inspector -> selected torrents"), fileCount];
                }
                basicString = [NSString stringWithFormat:@"%@, %@", fileString, basicString];
            }
            self.fBasicInfoField.stringValue = basicString;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_8 && !TR_MACOS_SDK_BEFORE_10_8
            NSByteCountFormatter* formatter = [[NSByteCountFormatter alloc] init];
            formatter.allowedUnits = NSByteCountFormatterUseBytes;
            self.fBasicInfoField.toolTip = [formatter stringFromByteCount:torrent.size];
#else
            self.fBasicInfoField.toolTip = [NSString stringWithFormat:@"%llu bytes", static_cast<unsigned long long>(torrent.size)];
#endif
        }
        else
        {
            self.fBasicInfoField.stringValue = NSLocalizedString(@"Magnetized transfer", "Inspector -> selected torrents");
            self.fBasicInfoField.toolTip = nil;
        }
        self.fBasicInfoField.hidden = NO;

        self.fNoneSelectedField.hidden = YES;
    }

    [self.fGeneralViewController setInfoForTorrents:self.fTorrents];
    [self.fActivityViewController setInfoForTorrents:self.fTorrents];
    [self.fTrackersViewController setInfoForTorrents:self.fTorrents];
    [self.fPeersViewController setInfoForTorrents:self.fTorrents];
    [self.fFileViewController setInfoForTorrents:self.fTorrents];
    [self.fOptionsViewController setInfoForTorrents:self.fTorrents];

    [self.fViewController updateInfo];
}

- (void)resetInfoForTorrent:(NSNotification*)notification
{
    Torrent* torrent = notification.userInfo[@"Torrent"];
    if (self.fTorrents && (!torrent || [self.fTorrents containsObject:torrent]))
    {
        [self resetInfo];
    }
}

@end
