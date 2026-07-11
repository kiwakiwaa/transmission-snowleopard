// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#import "ObjectiveCCompatibility.h"
#import "LegacyRegularExpression.h"

#ifndef TR_MACOS_OBJC_FRAGILE_RUNTIME
#define TR_MACOS_OBJC_FRAGILE_RUNTIME 0
#endif

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#ifdef __cplusplus
extern "C" {
#endif
void libarc_support_clear_copied_object_pointer(void* object);
#ifdef __cplusplus
}
#endif

static inline void TRClearCopiedObjectPointer(void* object)
{
    libarc_support_clear_copied_object_pointer(object);
}
#endif

typedef void (^TRTimerBlock)(NSTimer* timer);

#if TR_MACOS_DEPLOYMENT_BEFORE_10_12
@interface NSTimer (TRLegacyBlockTimer)
+ (NSTimer*)tr_scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(TRTimerBlock)block;
+ (NSTimer*)tr_timerWithFireDate:(NSDate*)date interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(TRTimerBlock)block;
@end
#endif

static inline NSTimer* TRScheduledTimerWithTimeInterval(NSTimeInterval interval, BOOL repeats, TRTimerBlock block)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_12
    return [NSTimer tr_scheduledTimerWithTimeInterval:interval repeats:repeats block:block];
#else
    return [NSTimer scheduledTimerWithTimeInterval:interval repeats:repeats block:block];
#endif
}

static inline NSTimer* TRTimerWithFireDate(NSDate* date, NSTimeInterval interval, BOOL repeats, TRTimerBlock block)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_12
    return [NSTimer tr_timerWithFireDate:date interval:interval repeats:repeats block:block];
#else
    return [[NSTimer alloc] initWithFireDate:date interval:interval repeats:repeats block:block];
#endif
}

static inline void TRNormalizeLegacyTableHeaderAppearance(NSTableView* tableView)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_8 || !TR_MACOS_DEPLOYMENT_BEFORE_10_10
    (void)tableView;
#endif
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_8 && TR_MACOS_DEPLOYMENT_BEFORE_10_10
    NSTableHeaderView* oldHeaderView = tableView.headerView;
    if (oldHeaderView == nil)
    {
        return;
    }

    NSTableHeaderView* headerView = [[NSTableHeaderView alloc] initWithFrame:oldHeaderView.frame];
    headerView.autoresizingMask = oldHeaderView.autoresizingMask;
    tableView.headerView = headerView;

    NSRect headerFrame = tableView.headerView.frame;
    headerFrame.size.height = tableView.rowHeight + tableView.intercellSpacing.height;
    tableView.headerView.frame = headerFrame;

    NSScrollView* scrollView = tableView.enclosingScrollView;
    scrollView.drawsBackground = YES;
    scrollView.backgroundColor = [NSColor controlColor];
    scrollView.contentView.drawsBackground = YES;
    scrollView.contentView.backgroundColor = [NSColor controlColor];
    tableView.backgroundColor = [NSColor controlBackgroundColor];

    NSView* headerClipView = tableView.headerView.superview;
    if ([headerClipView isKindOfClass:[NSClipView class]])
    {
        NSClipView* clipView = (NSClipView*)headerClipView;
        clipView.drawsBackground = YES;
        clipView.backgroundColor = [NSColor controlColor];
    }

    for (NSTableColumn* tableColumn in tableView.tableColumns)
    {
        NSTableHeaderCell* headerCell = (NSTableHeaderCell*)tableColumn.headerCell;
        [headerCell setBackgroundColor:[NSColor headerColor]];
    }
#endif
}

#if TR_MACOS_SDK_BEFORE_10_7
typedef NSInteger NSLayoutAttribute;
typedef NSInteger NSLayoutRelation;
typedef NSUInteger NSLayoutFormatOptions;
typedef NSUInteger NSTableViewAnimationOptions;

static NSLayoutAttribute const NSLayoutAttributeNotAnAttribute = 0;
static NSLayoutAttribute const NSLayoutAttributeBottom = 4;
static NSLayoutAttribute const NSLayoutAttributeWidth = 7;
static NSLayoutAttribute const NSLayoutAttributeHeight = 8;

static NSLayoutRelation const NSLayoutRelationLessThanOrEqual = -1;
static NSLayoutRelation const NSLayoutRelationEqual = 0;
static NSLayoutRelation const NSLayoutRelationGreaterThanOrEqual = 1;

static NSTableViewAnimationOptions const NSTableViewAnimationSlideLeft = 0;
static NSTableViewAnimationOptions const NSTableViewAnimationSlideDown = 0;
static NSTableViewAnimationOptions const NSTableViewAnimationSlideUp = 0;
static NSTableViewAnimationOptions const NSTableViewAnimationEffectFade = 0;

#ifndef NSWindowCollectionBehaviorFullScreenPrimary
#define NSWindowCollectionBehaviorFullScreenPrimary NSWindowCollectionBehaviorFullScreenNone
#endif

static inline uint32_t arc4random_uniform(uint32_t upper_bound)
{
    return upper_bound == 0 ? 0 : arc4random() % upper_bound;
}

#undef NSAssert
#define NSAssert(condition, desc, ...) \
    do \
    { \
        if (!(condition)) \
        { \
            [NSException raise:NSInternalInconsistencyException format:(desc), ##__VA_ARGS__]; \
        } \
    } while (0)

@interface NSLayoutConstraint : NSObject
@property(nonatomic) CGFloat constant;
@property(nonatomic, getter=isActive) BOOL active;
@property(nonatomic, assign) id firstItem;
@property(nonatomic, assign) id secondItem;
@property(nonatomic) NSLayoutAttribute firstAttribute;
@property(nonatomic, copy) NSDictionary* animations;
- (id)animator;
+ (instancetype)constraintWithItem:(id)view1
                         attribute:(NSLayoutAttribute)attr1
                         relatedBy:(NSLayoutRelation)relation
                            toItem:(id)view2
                         attribute:(NSLayoutAttribute)attr2
                        multiplier:(CGFloat)multiplier
                          constant:(CGFloat)c;
+ (NSArray*)constraintsWithVisualFormat:(NSString*)format options:(NSLayoutFormatOptions)opts metrics:(NSDictionary*)metrics views:(NSDictionary*)views;
+ (void)activateConstraints:(NSArray*)constraints;
+ (void)deactivateConstraints:(NSArray*)constraints;
@end

@interface NSView (TRLegacyAutoLayout)
@property(nonatomic) BOOL translatesAutoresizingMaskIntoConstraints;
@property(nonatomic, copy) NSString* identifier;
@property(nonatomic, readonly) NSSize fittingSize;
@property(nonatomic, readonly) NSArray* constraints;
- (void)addConstraint:(NSLayoutConstraint*)constraint;
- (void)addConstraints:(NSArray*)constraints;
- (void)removeConstraint:(NSLayoutConstraint*)constraint;
- (void)removeConstraints:(NSArray*)constraints;
- (void)layout;
@end

@interface NSTableCellView : NSView
@property(nonatomic, retain) NSTextField* textField;
@property(nonatomic, retain) NSImageView* imageView;
@property(nonatomic, retain) id objectValue;
@property(nonatomic) NSBackgroundStyle backgroundStyle;
@end

@interface NSTableView (TRLegacyTableView)
@property(nonatomic) BOOL floatsGroupRows;
- (void)beginUpdates;
- (void)endUpdates;
- (void)moveRowAtIndex:(NSInteger)oldIndex toIndex:(NSInteger)newIndex;
- (void)insertRowsAtIndexes:(NSIndexSet*)indexes withAnimation:(NSTableViewAnimationOptions)animationOptions;
- (void)removeRowsAtIndexes:(NSIndexSet*)indexes withAnimation:(NSTableViewAnimationOptions)animationOptions;
- (id)makeViewWithIdentifier:(NSString*)identifier owner:(id)owner;
- (NSView*)viewAtColumn:(NSInteger)column row:(NSInteger)row makeIfNecessary:(BOOL)makeIfNecessary;
- (NSInteger)rowForView:(NSView*)view;
@end

@interface NSOutlineView (TRLegacyTableAnimations)
- (void)beginUpdates;
- (void)endUpdates;
- (void)insertItemsAtIndexes:(NSIndexSet*)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions;
- (void)removeItemsAtIndexes:(NSIndexSet*)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions;
- (void)moveItemAtIndex:(NSInteger)fromIndex inParent:(id)oldParent toIndex:(NSInteger)toIndex inParent:(id)newParent;
@end

@interface NSAnimationContext (TRLegacyAnimationContext)
@property(nonatomic) BOOL allowsImplicitAnimation;
@property(nonatomic, copy) void (^completionHandler)(void);
+ (void)runAnimationGroup:(void (^)(NSAnimationContext* context))changes completionHandler:(void (^)(void))completionHandler;
@end

@protocol NSWindowRestoration
@end

@interface NSWindow (TRLegacyRestoration)
@property(nonatomic) BOOL restorable;
@property(nonatomic, assign) Class restorationClass;
- (NSRect)convertRectToScreen:(NSRect)rect;
@end

#ifndef NSImageNameShareTemplate
#define NSImageNameShareTemplate @"NSShareTemplate"
#endif

#ifndef NSFullScreenWindowMask
#define NSFullScreenWindowMask 0
#endif

#ifndef DISPATCH_QUEUE_SERIAL
#define DISPATCH_QUEUE_SERIAL NULL
#endif
#endif

#if TR_MACOS_SDK_BEFORE_10_8
#undef NSAssert
#define NSAssert(condition, desc, ...) \
    do \
    { \
        if (!(condition)) \
        { \
            [NSException raise:NSInternalInconsistencyException format:(desc), ##__VA_ARGS__]; \
        } \
    } while (0)

#ifndef NSImageNameShareTemplate
#define NSImageNameShareTemplate @"NSShareTemplate"
#endif
#endif

#if TR_MACOS_SDK_BEFORE_10_8
@interface NSImage (TRLegacyImageDrawing)
+ (NSImage*)imageWithSize:(NSSize)size flipped:(BOOL)drawingHandlerShouldBeCalledWithFlippedContext drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler;
@end

@protocol NSURLConnectionDataDelegate
@end

@protocol NSURLConnectionDownloadDelegate
@end

@interface NSBundle (TRLegacyNibLoading)
- (BOOL)loadNibNamed:(NSString*)nibName owner:(id)owner topLevelObjects:(NSArray**)topLevelObjects;
@end

@interface NSFileManager (TRLegacyTrash)
- (BOOL)trashItemAtURL:(NSURL*)url resultingItemURL:(NSURL**)outResultingURL error:(NSError**)error;
@end

@class NSSharingService;
@class NSSharingServicePicker;
@class NSSharingContentScope;

@protocol NSSharingServiceDelegate
@end

@protocol NSSharingServicePickerDelegate
@end

@interface NSSharingService : NSObject
@property(nonatomic, copy) NSString* title;
@property(nonatomic, retain) NSImage* image;
@property(nonatomic, assign) id<NSSharingServiceDelegate> delegate;
+ (NSArray*)sharingServicesForItems:(NSArray*)items;
- (void)performWithItems:(NSArray*)items;
@end

@interface NSSharingServicePicker : NSObject
@property(nonatomic, assign) id<NSSharingServicePickerDelegate> delegate;
- (instancetype)initWithItems:(NSArray*)items;
- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView*)positioningView preferredEdge:(NSRectEdge)preferredEdge;
@end

@interface NSSharingContentScope : NSObject
@end
#endif

#if TR_MACOS_SDK_BEFORE_10_8 && !TR_MACOS_SDK_BEFORE_10_7
@interface NSAnimationContext (TRLegacyImplicitAnimation)
@property(nonatomic) BOOL allowsImplicitAnimation;
@end
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
#import "LegacyPopover.h"
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8
@interface NSArray (TRObjectSubscripting)
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
@end

@interface NSMutableArray (TRObjectSubscripting)
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;
@end

@interface NSDictionary (TRObjectSubscripting)
- (id)objectForKeyedSubscript:(id)key;
@end

@interface NSMutableDictionary (TRObjectSubscripting)
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;
@end
#endif

#import "LegacyColors.h"
#import "LegacyConstraints.h"
#import "LegacyPowerActivity.h"
#import "LegacySegmentedControl.h"
#import "LegacySheets.h"
#import "LegacySymbols.h"
#import "LegacyTitlebarAccessory.h"

#if TR_MACOS_SDK_BEFORE_10_12
#define NSBezelStyleTexturedRounded NSTexturedRoundedBezelStyle
#endif

#if TR_MACOS_SDK_BEFORE_10_12
#define NSBackgroundStyleEmphasized NSBackgroundStyleDark
#endif

#if TR_MACOS_SDK_BEFORE_10_12
#define NSEventModifierFlagOption NSAlternateKeyMask
#define NSEventModifierFlagCommand NSCommandKeyMask
#endif

#if TR_MACOS_SDK_BEFORE_10_13
#define TRPasteboardTypeFileURL NSFilenamesPboardType
#define TRPasteboardTypeURL NSURLPboardType
#else
#define TRPasteboardTypeFileURL NSPasteboardTypeFileURL
#define TRPasteboardTypeURL NSPasteboardTypeURL
#endif

#if TR_MACOS_SDK_BEFORE_10_10
#define TRURLQuarantinePropertiesKey @"NSURLQuarantinePropertiesKey"
#else
#define TRURLQuarantinePropertiesKey NSURLQuarantinePropertiesKey
#endif

static inline NSEvent* NSAppCurrentEvent(void)
{
    return [NSApp currentEvent];
}

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#endif

#if !__has_feature(nullability)
#ifndef nullable
#define nullable
#endif
#ifndef nonnull
#define nonnull
#endif
#ifndef __kindof
#define __kindof
#endif
#ifndef _Nullable
#define _Nullable
#endif
#ifndef _Nonnull
#define _Nonnull
#endif
#endif

#ifndef API_AVAILABLE
#define API_AVAILABLE(...)
#endif

#ifndef NS_UNAVAILABLE
#define NS_UNAVAILABLE
#endif

#ifndef CFBridgingRetain
#define CFBridgingRetain(X) ((__bridge_retained CFTypeRef)(X))
#endif

#ifndef CFBridgingRelease
#define CFBridgingRelease(X) ((__bridge_transfer id)(X))
#endif

#ifndef NS_TYPED_EXTENSIBLE_ENUM
#define NS_TYPED_EXTENSIBLE_ENUM
#endif

#ifndef __AVAILABILITY_INTERNAL__MAC_NSURLSESSION_AVAILABLE
#define __AVAILABILITY_INTERNAL__MAC_NSURLSESSION_AVAILABLE
#endif

#ifndef NSMenuItemValidation
#define NSMenuItemValidation NSUserInterfaceValidations
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@interface NSPredicate (TRSecureCodingEvaluation)
- (void)allowEvaluation;
@end
#endif

#if TR_MACOS_SDK_BEFORE_10_13
typedef NSInteger NSControlStateValue;
static NSControlStateValue const NSControlStateValueMixed = NSMixedState;
static NSControlStateValue const NSControlStateValueOff = NSOffState;
static NSControlStateValue const NSControlStateValueOn = NSOnState;
#endif

#if TR_MACOS_SDK_BEFORE_10_12
#define NSAlertStyleWarning NSWarningAlertStyle
#define NSAlertStyleCritical NSCriticalAlertStyle
#define NSAlertStyleInformational NSInformationalAlertStyle
#endif

#if TR_MACOS_SDK_BEFORE_10_12
#define TRFullScreenWindowMask NSFullScreenWindowMask
#define TRLeftMouseDownMask NSLeftMouseDownMask
#else
#define TRFullScreenWindowMask NSWindowStyleMaskFullScreen
#define TRLeftMouseDownMask NSEventMaskLeftMouseDown
#endif

#ifndef NSWindowCollectionBehaviorFullScreenNone
#define NSWindowCollectionBehaviorFullScreenNone 0
#endif

#if TR_MACOS_SDK_BEFORE_10_12
#define NSCompositingOperationSourceOver NSCompositeSourceOver
#define NSCompositingOperationSourceAtop NSCompositeSourceAtop
#define NSCompositingOperationSourceIn NSCompositeSourceIn
#define NSCompositingOperationCopy NSCompositeCopy
#endif

NS_ASSUME_NONNULL_BEGIN

// Compatibility declarations to build `@available(macOS 13.0, *)` code with older Xcode 12.5.1 (the last macOS 11.0 compatible Xcode)
#ifndef __MAC_13_0

typedef NS_ENUM(NSInteger, NSColorWellStyle) {
    NSColorWellStyleMinimal = 1,
} API_AVAILABLE(macos(13.0));

@interface NSColorWell ()
@property(assign) NSColorWellStyle colorWellStyle API_AVAILABLE(macos(13.0));
@end

#endif

NS_ASSUME_NONNULL_END

#if TR_MACOS_SDK_BEFORE_10_12
#define NSTextAlignmentRight NSRightTextAlignment
#define NSTextAlignmentCenter NSCenterTextAlignment
#define NSTextAlignmentLeft NSLeftTextAlignment
#endif
