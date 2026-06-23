// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "CocoaCompatibility.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_12

@implementation NSTimer (TRLegacyBlockTimer)

+ (void)tr_fireBlockTimer:(NSTimer*)timer
{
    TRTimerBlock block = (TRTimerBlock)timer.userInfo;
    if (block != nil)
    {
        block(timer);
    }
}

+ (NSTimer*)tr_scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(TRTimerBlock)block
{
    return [self scheduledTimerWithTimeInterval:interval target:self selector:@selector(tr_fireBlockTimer:) userInfo:[block copy] repeats:repeats];
}

+ (NSTimer*)tr_timerWithFireDate:(NSDate*)date interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(TRTimerBlock)block
{
    return [[self alloc] initWithFireDate:date interval:interval target:self selector:@selector(tr_fireBlockTimer:) userInfo:[block copy] repeats:repeats];
}

@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_7

#import <objc/runtime.h>

static char TRLegacyTableUpdateDepthKey;
static char TRLegacyTableNeedsReloadKey;

static NSInteger TRLegacyTableUpdateDepth(NSTableView* tableView)
{
    return [objc_getAssociatedObject(tableView, &TRLegacyTableUpdateDepthKey) integerValue];
}

static void TRLegacySetTableUpdateDepth(NSTableView* tableView, NSInteger depth)
{
    objc_setAssociatedObject(
        tableView,
        &TRLegacyTableUpdateDepthKey,
        [NSNumber numberWithInteger:MAX(0, depth)],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL TRLegacyTableNeedsReload(NSTableView* tableView)
{
    return [objc_getAssociatedObject(tableView, &TRLegacyTableNeedsReloadKey) boolValue];
}

static void TRLegacySetTableNeedsReload(NSTableView* tableView, BOOL needsReload)
{
    objc_setAssociatedObject(
        tableView,
        &TRLegacyTableNeedsReloadKey,
        [NSNumber numberWithBool:needsReload],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TRLegacyBeginTableUpdates(NSTableView* tableView)
{
    TRLegacySetTableUpdateDepth(tableView, TRLegacyTableUpdateDepth(tableView) + 1);
}

static void TRLegacyEndTableUpdates(NSTableView* tableView)
{
    NSInteger const depth = TRLegacyTableUpdateDepth(tableView) - 1;
    TRLegacySetTableUpdateDepth(tableView, depth);

    if (depth <= 0 && TRLegacyTableNeedsReload(tableView))
    {
        TRLegacySetTableNeedsReload(tableView, NO);
        [tableView reloadData];
    }
}

static void TRLegacyReloadTableWhenReady(NSTableView* tableView)
{
    if (TRLegacyTableUpdateDepth(tableView) > 0)
    {
        TRLegacySetTableNeedsReload(tableView, YES);
    }
    else
    {
        [tableView reloadData];
    }
}

@implementation NSLayoutConstraint

@synthesize constant;
@synthesize active;
@synthesize firstItem;
@synthesize secondItem;
@synthesize firstAttribute;
@synthesize animations;

+ (instancetype)constraintWithItem:(id)view1
                         attribute:(NSLayoutAttribute)attr1
                         relatedBy:(NSLayoutRelation)relation
                            toItem:(id)view2
                         attribute:(NSLayoutAttribute)attr2
                        multiplier:(CGFloat)multiplier
                          constant:(CGFloat)c
{
    NSLayoutConstraint* constraint = [[self alloc] init];
    constraint.firstItem = view1;
    constraint.secondItem = view2;
    constraint.firstAttribute = attr1;
    constraint.constant = c;
    return constraint;
}

+ (NSArray*)constraintsWithVisualFormat:(NSString*)format options:(NSLayoutFormatOptions)opts metrics:(NSDictionary*)metrics views:(NSDictionary*)views
{
    return @[];
}

+ (void)activateConstraints:(NSArray*)constraints
{
}

+ (void)deactivateConstraints:(NSArray*)constraints
{
}

- (id)animator
{
    return self;
}

@end

@implementation NSView (TRLegacyAutoLayout)

- (BOOL)translatesAutoresizingMaskIntoConstraints
{
    return YES;
}

- (void)setTranslatesAutoresizingMaskIntoConstraints:(BOOL)translatesAutoresizingMaskIntoConstraints
{
}

- (NSString*)identifier
{
    return nil;
}

- (void)setIdentifier:(NSString*)identifier
{
}

- (NSSize)fittingSize
{
    return self.frame.size;
}

- (NSArray*)constraints
{
    return @[];
}

- (void)addConstraint:(NSLayoutConstraint*)constraint
{
}

- (void)addConstraints:(NSArray*)constraints
{
}

- (void)removeConstraint:(NSLayoutConstraint*)constraint
{
}

- (void)removeConstraints:(NSArray*)constraints
{
}

- (void)layout
{
}

@end

@implementation NSTableCellView

@synthesize textField;
@synthesize imageView;
@synthesize objectValue;
@synthesize backgroundStyle;

@end

@implementation NSTableView (TRLegacyTableView)

- (BOOL)floatsGroupRows
{
    return NO;
}

- (void)setFloatsGroupRows:(BOOL)floatsGroupRows
{
}

- (void)beginUpdates
{
    TRLegacyBeginTableUpdates(self);
}

- (void)endUpdates
{
    TRLegacyEndTableUpdates(self);
}

- (void)moveRowAtIndex:(NSInteger)oldIndex toIndex:(NSInteger)newIndex
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)insertRowsAtIndexes:(NSIndexSet*)indexes withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)removeRowsAtIndexes:(NSIndexSet*)indexes withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (id)makeViewWithIdentifier:(NSString*)identifier owner:(id)owner
{
    return nil;
}

- (NSView*)viewAtColumn:(NSInteger)column row:(NSInteger)row makeIfNecessary:(BOOL)makeIfNecessary
{
    return nil;
}

- (NSInteger)rowForView:(NSView*)view
{
    if (view == nil)
    {
        return -1;
    }

    return [self rowAtPoint:[view convertPoint:NSZeroPoint toView:self]];
}

@end

@implementation NSOutlineView (TRLegacyTableAnimations)

- (void)beginUpdates
{
    TRLegacyBeginTableUpdates(self);
}

- (void)endUpdates
{
    TRLegacyEndTableUpdates(self);
}

- (void)insertItemsAtIndexes:(NSIndexSet*)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)removeItemsAtIndexes:(NSIndexSet*)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)moveItemAtIndex:(NSInteger)fromIndex inParent:(id)oldParent toIndex:(NSInteger)toIndex inParent:(id)newParent
{
    TRLegacyReloadTableWhenReady(self);
}

@end

@implementation NSAnimationContext (TRLegacyAnimationContext)

- (BOOL)allowsImplicitAnimation
{
    return NO;
}

- (void)setAllowsImplicitAnimation:(BOOL)allowsImplicitAnimation
{
}

- (void (^)(void))completionHandler
{
    return nil;
}

- (void)setCompletionHandler:(void (^)(void))completionHandler
{
}

+ (void)runAnimationGroup:(void (^)(NSAnimationContext* context))changes completionHandler:(void (^)(void))completionHandler
{
    if (changes != nil)
    {
        changes([NSAnimationContext currentContext]);
    }

    if (completionHandler != nil)
    {
        completionHandler();
    }
}

@end

@implementation NSWindow (TRLegacyRestoration)

- (BOOL)restorable
{
    return NO;
}

- (void)setRestorable:(BOOL)restorable
{
}

- (Class)restorationClass
{
    return Nil;
}

- (void)setRestorationClass:(Class)restorationClass
{
}

- (NSRect)convertRectToScreen:(NSRect)rect
{
    rect.origin = [self convertBaseToScreen:rect.origin];
    return rect;
}

@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8

@implementation NSFileManager (TRLegacyTrash)

- (BOOL)trashItemAtURL:(NSURL*)url resultingItemURL:(NSURL**)outResultingURL error:(NSError**)error
{
    if (outResultingURL != NULL)
    {
        *outResultingURL = nil;
    }

    if (![url isFileURL])
    {
        return NO;
    }

    NSString* path = url.path;
    NSInteger tag = 0;
    return [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                        source:path.stringByDeletingLastPathComponent
                                                   destination:@""
                                                         files:@[path.lastPathComponent]
                                                           tag:&tag];
}

@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8 && !TR_MACOS_DEPLOYMENT_BEFORE_10_7

@implementation NSAnimationContext (TRLegacyImplicitAnimation)

- (BOOL)allowsImplicitAnimation
{
    return NO;
}

- (void)setAllowsImplicitAnimation:(BOOL)allowsImplicitAnimation
{
}

@end

#endif

#if TR_MACOS_SDK_BEFORE_10_8

@implementation NSImage (TRLegacyImageDrawing)

+ (NSImage*)imageWithSize:(NSSize)size flipped:(BOOL)drawingHandlerShouldBeCalledWithFlippedContext drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler
{
    NSImage* image = [[self alloc] initWithSize:size];
    [image lockFocusFlipped:drawingHandlerShouldBeCalledWithFlippedContext];
    if (drawingHandler != nil)
    {
        drawingHandler(NSMakeRect(0, 0, size.width, size.height));
    }
    [image unlockFocus];
    return image;
}

@end

@implementation NSBundle (TRLegacyNibLoading)

- (BOOL)loadNibNamed:(NSString*)nibName owner:(id)owner topLevelObjects:(NSArray**)topLevelObjects
{
    if (topLevelObjects != NULL)
    {
        *topLevelObjects = nil;
    }

    return [NSBundle loadNibNamed:nibName owner:owner];
}

@end

@implementation NSSharingService

@synthesize title;
@synthesize image;
@synthesize delegate;

+ (NSArray*)sharingServicesForItems:(NSArray*)items
{
    return @[];
}

- (void)performWithItems:(NSArray*)items
{
}

@end

@implementation NSSharingServicePicker

@synthesize delegate;

- (instancetype)initWithItems:(NSArray*)items
{
    return [super init];
}

- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView*)positioningView preferredEdge:(NSRectEdge)preferredEdge
{
}

@end

@implementation NSSharingContentScope
@end

#endif
