// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyStackView.h"

static NSString* TRExpectedStackViewClassName()
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    return @"LegacyStackView";
#else
    return @"NSStackView";
#endif
}

BOOL TRCheckExpectedStackViewClass(id stackView, NSString* ownerName, NSString* outletName)
{
    NSString* expectedClassName = TRExpectedStackViewClassName();
    Class expectedClass = NSClassFromString(expectedClassName);
    if (expectedClass != Nil && [stackView isKindOfClass:expectedClass])
    {
        return YES;
    }

    NSString* actualClassName = stackView != nil ? NSStringFromClass([stackView class]) : @"nil";
    NSLog(
        @"Transmission stack-view class mismatch: %@.%@ expected %@ for this build path, got %@.",
        ownerName != nil ? ownerName : @"<unknown>",
        outletName != nil ? outletName : @"<unknown>",
        expectedClassName,
        actualClassName);
    return NO;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090

#import <float.h>
#import <math.h>

static CGFloat const TRLegacyStackViewDefaultSpacing = 8.0;
static CGFloat const TRLegacyStackViewDefaultHuggingPriority = 250.0;
static CGFloat const TRLegacyStackViewDefaultClippingResistancePriority = 1000.0;
static CGFloat const TRLegacyStackViewAlignmentTolerance = 1.0;

static BOOL TRLegacyStackViewVisibilityPriorityIsNotVisible(TRLegacyStackViewVisibilityPriority priority)
{
    return priority <= TRLegacyStackViewVisibilityPriorityNotVisible;
}

@interface LegacyStackView ()
{
    NSMutableArray* fLeadingViews;
    NSMutableArray* fCenterViews;
    NSMutableArray* fTrailingViews;
    NSMutableSet* fDetachedViews;
    NSMutableDictionary* fVisibilityPriorities;
    BOOL fUpdatingSubviews;
    BOOL fNeedsLegacyLayout;
    BOOL fLayingOutLegacySubviews;
    CGFloat fLeadingOffset;
    CGFloat fTrailingOffset;
    CGFloat fCenterOffset;
    CGFloat fTopOffset;
    CGFloat fHorizontalHuggingPriority;
    CGFloat fVerticalHuggingPriority;
    CGFloat fHorizontalClippingResistancePriority;
    CGFloat fVerticalClippingResistancePriority;
}

- (void)commonInit;
- (void)ensureArrangedSubviewsFromCurrentSubviews;
- (void)inferLegacyLayoutFromInitialFrames;
- (void)invalidateLegacyLayout;
- (NSArray*)visibleLegacySubviews;
- (NSSize)legacyContentSize;
- (NSSize)legacySizeForSubview:(NSView*)subview;
- (NSMutableArray*)viewsForGravity:(TRLegacyStackViewGravity)gravity;
- (BOOL)containsArrangedSubview:(NSView*)view;
- (void)attachArrangedSubviewIfNeeded:(NSView*)view;
- (void)detachArrangedSubviewIfNeeded:(NSView*)view;
- (void)removeArrangedSubview:(NSView*)view removeFromSuperview:(BOOL)removeFromSuperview;
- (void)replaceViewsInGravity:(TRLegacyStackViewGravity)gravity withViews:(NSArray*)views;
- (CGFloat)legacyHorizontalOriginForSubviewWidth:(CGFloat)width;
- (CGFloat)legacyVerticalOriginForSubviewHeight:(CGFloat)height;
- (BOOL)legacyAlignmentIsVerticalCompatible:(TRLegacyStackViewAlignment)alignment;
@end

@implementation LegacyStackView

+ (instancetype)stackViewWithViews:(NSArray*)views
{
    LegacyStackView* stackView = [[self alloc] initWithFrame:NSZeroRect];
    [stackView setViews:views inGravity:TRLegacyStackViewGravityCenter];
    return stackView;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self commonInit];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        [self commonInit];
    }

    return self;
}

- (void)commonInit
{
    fLeadingViews = [[NSMutableArray alloc] init];
    fCenterViews = [[NSMutableArray alloc] init];
    fTrailingViews = [[NSMutableArray alloc] init];
    fDetachedViews = [[NSMutableSet alloc] init];
    fVisibilityPriorities = [[NSMutableDictionary alloc] init];

    _orientation = TRLegacyStackViewOrientationHorizontal;
    _alignment = TRLegacyStackViewAlignmentCenterY;
    _spacing = TRLegacyStackViewDefaultSpacing;
    _detachesHiddenViews = YES;

    fHorizontalHuggingPriority = TRLegacyStackViewDefaultHuggingPriority;
    fVerticalHuggingPriority = TRLegacyStackViewDefaultHuggingPriority;
    fHorizontalClippingResistancePriority = TRLegacyStackViewDefaultClippingResistancePriority;
    fVerticalClippingResistancePriority = TRLegacyStackViewDefaultClippingResistancePriority;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self ensureArrangedSubviewsFromCurrentSubviews];
    [self inferLegacyLayoutFromInitialFrames];
    [self layoutLegacySubviews];
}

- (void)viewWillDraw
{
    [super viewWillDraw];
    if (fNeedsLegacyLayout)
    {
        [self layoutLegacySubviews];
    }
}

- (void)didAddSubview:(NSView*)subview
{
    [super didAddSubview:subview];

    if (!fUpdatingSubviews && ![self containsArrangedSubview:subview])
    {
        [fCenterViews addObject:subview];
        [self invalidateLegacyLayout];
    }
}

- (void)willRemoveSubview:(NSView*)subview
{
    [super willRemoveSubview:subview];

    if (!fUpdatingSubviews)
    {
        [self removeArrangedSubview:subview removeFromSuperview:NO];
    }
}

- (void)setFrameSize:(NSSize)newSize
{
    NSSize const oldSize = self.frame.size;
    [super setFrameSize:newSize];
    if (!NSEqualSizes(oldSize, newSize))
    {
        [self invalidateLegacyLayout];
        [self layoutLegacySubviews];
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
    [super resizeSubviewsWithOldSize:oldSize];
    [self invalidateLegacyLayout];
    [self layoutLegacySubviews];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
- (void)layout
{
    [super layout];
    if (fNeedsLegacyLayout)
    {
        [self layoutLegacySubviews];
    }
}
#endif

- (NSArray*)arrangedSubviews
{
    return self.views;
}

- (NSArray*)views
{
    NSMutableArray* views = [NSMutableArray arrayWithCapacity:fLeadingViews.count + fCenterViews.count + fTrailingViews.count];
    [views addObjectsFromArray:fLeadingViews];
    [views addObjectsFromArray:fCenterViews];
    [views addObjectsFromArray:fTrailingViews];
    return views;
}

- (NSArray*)detachedViews
{
    return fDetachedViews.allObjects;
}

- (void)setOrientation:(TRLegacyStackViewOrientation)orientation
{
    if (_orientation == orientation)
    {
        return;
    }

    _orientation = orientation;

    if (_orientation == TRLegacyStackViewOrientationVertical && ![self legacyAlignmentIsVerticalCompatible:self.alignment])
    {
        [self setAlignment:TRLegacyStackViewAlignmentCenterX];
    }
    else if (_orientation == TRLegacyStackViewOrientationHorizontal && [self legacyAlignmentIsVerticalCompatible:self.alignment])
    {
        [self setAlignment:TRLegacyStackViewAlignmentCenterY];
    }

    [self invalidateLegacyLayout];
}

- (void)setAlignment:(TRLegacyStackViewAlignment)alignment
{
    if (_alignment == alignment)
    {
        return;
    }

    _alignment = alignment;

    if (self.orientation == TRLegacyStackViewOrientationVertical && ![self legacyAlignmentIsVerticalCompatible:alignment])
    {
        [self setOrientation:TRLegacyStackViewOrientationHorizontal];
    }
    else if (self.orientation == TRLegacyStackViewOrientationHorizontal && [self legacyAlignmentIsVerticalCompatible:alignment])
    {
        [self setOrientation:TRLegacyStackViewOrientationVertical];
    }

    [self invalidateLegacyLayout];
}

- (void)setSpacing:(CGFloat)spacing
{
    if (fabs(_spacing - spacing) <= DBL_EPSILON)
    {
        return;
    }

    _spacing = spacing;
    [self invalidateLegacyLayout];
}

- (void)setDetachesHiddenViews:(BOOL)detachesHiddenViews
{
    if (_detachesHiddenViews == detachesHiddenViews)
    {
        return;
    }

    _detachesHiddenViews = detachesHiddenViews;
    [self invalidateLegacyLayout];
}

- (void)addArrangedSubview:(NSView*)view
{
    [self addView:view inGravity:TRLegacyStackViewGravityCenter];
}

- (void)insertArrangedSubview:(NSView*)view atIndex:(NSUInteger)index
{
    [self insertView:view atIndex:index inGravity:TRLegacyStackViewGravityCenter];
}

- (void)removeArrangedSubview:(NSView*)view
{
    [self removeArrangedSubview:view removeFromSuperview:YES];
}

- (void)addView:(NSView*)view inGravity:(TRLegacyStackViewGravity)gravity
{
    [self insertView:view atIndex:[self viewsInGravity:gravity].count inGravity:gravity];
}

- (void)insertView:(NSView*)view atIndex:(NSUInteger)index inGravity:(TRLegacyStackViewGravity)gravity
{
    if (view == nil)
    {
        return;
    }

    NSMutableArray* views = [self viewsForGravity:gravity];
    if (views == nil)
    {
        return;
    }

    [self removeArrangedSubview:view removeFromSuperview:NO];
    [views insertObject:view atIndex:MIN(index, views.count)];
    [fDetachedViews removeObject:view];
    [self attachArrangedSubviewIfNeeded:view];
    [self invalidateLegacyLayout];
}

- (void)removeView:(NSView*)view
{
    if (![self containsArrangedSubview:view])
    {
        [NSException raise:NSInternalInconsistencyException format:@"View %@ is not (and has to be) in stack view %@.", view, self];
    }

    [self removeArrangedSubview:view removeFromSuperview:YES];
}

- (NSArray*)viewsInGravity:(TRLegacyStackViewGravity)gravity
{
    return [[self viewsForGravity:gravity] copy];
}

- (void)setViews:(NSArray*)views inGravity:(TRLegacyStackViewGravity)gravity
{
    [self replaceViewsInGravity:gravity withViews:views];
}

- (void)setVisibilityPriority:(TRLegacyStackViewVisibilityPriority)priority forView:(NSView*)view
{
    if (![self containsArrangedSubview:view])
    {
        [NSException raise:NSInternalInconsistencyException format:@"View %@ is not (and has to be) in stack view %@.", view, self];
    }

    TRLegacyStackViewVisibilityPriority const oldPriority = [self visibilityPriorityForView:view];
    BOOL const oldPriorityNotVisible = TRLegacyStackViewVisibilityPriorityIsNotVisible(oldPriority);
    BOOL const newPriorityNotVisible = TRLegacyStackViewVisibilityPriorityIsNotVisible(priority);
    NSValue* key = [NSValue valueWithNonretainedObject:view];
    [fVisibilityPriorities setObject:[NSNumber numberWithDouble:priority] forKey:key];

    if (oldPriorityNotVisible == newPriorityNotVisible)
    {
        return;
    }

    if (oldPriorityNotVisible && !newPriorityNotVisible)
    {
        [fDetachedViews removeObject:view];
        view.hidden = NO;
        [self attachArrangedSubviewIfNeeded:view];
    }
    else if (!oldPriorityNotVisible && newPriorityNotVisible)
    {
        view.hidden = YES;
        [fDetachedViews addObject:view];
        [self detachArrangedSubviewIfNeeded:view];
    }

    [self invalidateLegacyLayout];
}

- (TRLegacyStackViewVisibilityPriority)visibilityPriorityForView:(NSView*)view
{
    if (![self containsArrangedSubview:view])
    {
        [NSException raise:NSInternalInconsistencyException format:@"View %@ is not (and has to be) in stack view %@.", view, self];
    }

    NSNumber* priority = [fVisibilityPriorities objectForKey:[NSValue valueWithNonretainedObject:view]];
    return priority != nil ? priority.doubleValue : TRLegacyStackViewVisibilityPriorityMustHold;
}

- (CGFloat)huggingPriorityForOrientation:(TRLegacyStackViewOrientation)orientation
{
    return orientation == TRLegacyStackViewOrientationVertical ? fVerticalHuggingPriority : fHorizontalHuggingPriority;
}

- (void)setHuggingPriority:(CGFloat)priority forOrientation:(TRLegacyStackViewOrientation)orientation
{
    if (orientation == TRLegacyStackViewOrientationVertical)
    {
        fVerticalHuggingPriority = priority;
    }
    else
    {
        fHorizontalHuggingPriority = priority;
    }

    [self invalidateLegacyLayout];
}

- (CGFloat)clippingResistancePriorityForOrientation:(TRLegacyStackViewOrientation)orientation
{
    return orientation == TRLegacyStackViewOrientationVertical ? fVerticalClippingResistancePriority :
                                                                fHorizontalClippingResistancePriority;
}

- (void)setClippingResistancePriority:(CGFloat)priority forOrientation:(TRLegacyStackViewOrientation)orientation
{
    if (orientation == TRLegacyStackViewOrientationVertical)
    {
        fVerticalClippingResistancePriority = priority;
    }
    else
    {
        fHorizontalClippingResistancePriority = priority;
    }

    [self invalidateLegacyLayout];
}

- (void)invalidateLegacyLayout
{
    fNeedsLegacyLayout = YES;

    SEL invalidateSelector = @selector(invalidateIntrinsicContentSize);
    if ([self respondsToSelector:invalidateSelector])
    {
        void (*invalidateContentSize)(id, SEL) = (void (*)(id, SEL))[self methodForSelector:invalidateSelector];
        invalidateContentSize(self, invalidateSelector);
    }

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    if ([self respondsToSelector:@selector(setNeedsLayout:)])
    {
        self.needsLayout = YES;
    }
#endif

    [self setNeedsDisplay:YES];
    [self.superview setNeedsDisplay:YES];
}

- (void)ensureArrangedSubviewsFromCurrentSubviews
{
    if (fLeadingViews.count != 0 || fCenterViews.count != 0 || fTrailingViews.count != 0)
    {
        return;
    }

    [fCenterViews addObjectsFromArray:self.subviews];
}

- (void)inferLegacyLayoutFromInitialFrames
{
    NSArray* visibleSubviews = self.visibleLegacySubviews;
    if (visibleSubviews.count == 0)
    {
        return;
    }

    CGFloat minCenterX = FLT_MAX;
    CGFloat maxCenterX = -FLT_MAX;
    CGFloat minCenterY = FLT_MAX;
    CGFloat maxCenterY = -FLT_MAX;

    for (NSView* subview in visibleSubviews)
    {
        NSRect const frame = subview.frame;
        CGFloat const centerX = NSMidX(frame);
        CGFloat const centerY = NSMidY(frame);
        minCenterX = MIN(minCenterX, centerX);
        maxCenterX = MAX(maxCenterX, centerX);
        minCenterY = MIN(minCenterY, centerY);
        maxCenterY = MAX(maxCenterY, centerY);
    }

    _orientation = maxCenterY - minCenterY > maxCenterX - minCenterX ? TRLegacyStackViewOrientationVertical :
                                                                        TRLegacyStackViewOrientationHorizontal;

    NSArray* sortedSubviews;
    if (self.orientation == TRLegacyStackViewOrientationHorizontal)
    {
        sortedSubviews = [visibleSubviews sortedArrayUsingComparator:^NSComparisonResult(id firstObject, id secondObject) {
            NSView* firstView = firstObject;
            NSView* secondView = secondObject;
            CGFloat const firstX = NSMinX(firstView.frame);
            CGFloat const secondX = NSMinX(secondView.frame);
            return firstX < secondX ? NSOrderedAscending : firstX > secondX ? NSOrderedDescending : NSOrderedSame;
        }];
    }
    else
    {
        sortedSubviews = [visibleSubviews sortedArrayUsingComparator:^NSComparisonResult(id firstObject, id secondObject) {
            NSView* firstView = firstObject;
            NSView* secondView = secondObject;
            CGFloat const firstY = NSMaxY(firstView.frame);
            CGFloat const secondY = NSMaxY(secondView.frame);
            return firstY > secondY ? NSOrderedAscending : firstY < secondY ? NSOrderedDescending : NSOrderedSame;
        }];
    }

    if (fLeadingViews.count == 0 && fTrailingViews.count == 0 && fCenterViews.count == visibleSubviews.count)
    {
        [fCenterViews setArray:sortedSubviews];
    }

    NSView* firstView = [sortedSubviews objectAtIndex:0];
    fLeadingOffset = NSMinX(firstView.frame);
    fTopOffset = MAX(0.0, NSHeight(self.bounds) - NSMaxY(firstView.frame));

    if (self.orientation == TRLegacyStackViewOrientationHorizontal)
    {
        _alignment = TRLegacyStackViewAlignmentCenterY;
    }
    else
    {
        CGFloat minMinX = FLT_MAX;
        CGFloat maxMinX = -FLT_MAX;
        CGFloat minMaxX = FLT_MAX;
        CGFloat maxMaxX = -FLT_MAX;
        CGFloat minMidX = FLT_MAX;
        CGFloat maxMidX = -FLT_MAX;

        for (NSView* subview in sortedSubviews)
        {
            NSRect const frame = subview.frame;
            minMinX = MIN(minMinX, NSMinX(frame));
            maxMinX = MAX(maxMinX, NSMinX(frame));
            minMaxX = MIN(minMaxX, NSMaxX(frame));
            maxMaxX = MAX(maxMaxX, NSMaxX(frame));
            minMidX = MIN(minMidX, NSMidX(frame));
            maxMidX = MAX(maxMidX, NSMidX(frame));
        }

        if (maxMaxX - minMaxX <= TRLegacyStackViewAlignmentTolerance && maxMinX - minMinX > TRLegacyStackViewAlignmentTolerance)
        {
            _alignment = TRLegacyStackViewAlignmentTrailing;
            fTrailingOffset = maxMaxX - NSWidth(self.bounds);
        }
        else if (maxMinX - minMinX <= TRLegacyStackViewAlignmentTolerance)
        {
            _alignment = TRLegacyStackViewAlignmentLeading;
            fLeadingOffset = minMinX;
        }
        else if (maxMidX - minMidX <= TRLegacyStackViewAlignmentTolerance)
        {
            _alignment = TRLegacyStackViewAlignmentCenterX;
            fCenterOffset = ((minMidX + maxMidX) / 2.0) - (NSWidth(self.bounds) / 2.0);
        }
        else
        {
            _alignment = TRLegacyStackViewAlignmentLeading;
            fLeadingOffset = minMinX;
        }
    }

    if (sortedSubviews.count < 2)
    {
        return;
    }

    CGFloat totalSpacing = 0.0;
    NSUInteger spacingCount = 0;
    for (NSUInteger i = 1; i < sortedSubviews.count; ++i)
    {
        NSView* previousView = [sortedSubviews objectAtIndex:i - 1];
        NSView* currentView = [sortedSubviews objectAtIndex:i];

        CGFloat spacing;
        if (self.orientation == TRLegacyStackViewOrientationHorizontal)
        {
            spacing = NSMinX(currentView.frame) - NSMaxX(previousView.frame);
        }
        else
        {
            spacing = NSMinY(previousView.frame) - NSMaxY(currentView.frame);
        }

        if (spacing >= 0.0)
        {
            totalSpacing += spacing;
            ++spacingCount;
        }
    }

    if (spacingCount > 0)
    {
        _spacing = totalSpacing / spacingCount;
    }
}

- (NSArray*)visibleLegacySubviews
{
    [self ensureArrangedSubviewsFromCurrentSubviews];

    NSMutableArray* visibleSubviews = [NSMutableArray arrayWithCapacity:self.views.count];
    for (NSView* subview in self.views)
    {
        BOOL const detached = [fDetachedViews containsObject:subview];
        BOOL const hiddenAndDetached = self.detachesHiddenViews && subview.isHidden;
        if (!detached && !hiddenAndDetached)
        {
            [visibleSubviews addObject:subview];
        }
    }

    return visibleSubviews;
}

- (NSSize)legacySizeForSubview:(NSView*)subview
{
    NSSize size = NSZeroSize;

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    if ([subview respondsToSelector:@selector(fittingSize)])
    {
        size = subview.fittingSize;
    }
#endif
    NSRect const frame = subview.frame;
    if (size.width <= 0.0)
    {
        size.width = NSWidth(frame);
    }
    if (size.height <= 0.0)
    {
        size.height = NSHeight(frame);
    }
    return size;
}

- (NSSize)legacyContentSize
{
    NSArray* visibleSubviews = self.visibleLegacySubviews;
    if (visibleSubviews.count == 0)
    {
        return NSZeroSize;
    }

    CGFloat const spacing = self.spacing;
    NSSize size = NSZeroSize;

    if (self.orientation == TRLegacyStackViewOrientationHorizontal)
    {
        size.width = spacing * (visibleSubviews.count - 1);
        for (NSView* subview in visibleSubviews)
        {
            NSSize const subviewSize = [self legacySizeForSubview:subview];
            size.width += subviewSize.width;
            size.height = MAX(size.height, subviewSize.height);
        }
    }
    else
    {
        size.height = spacing * (visibleSubviews.count - 1);
        for (NSView* subview in visibleSubviews)
        {
            NSSize const subviewSize = [self legacySizeForSubview:subview];
            size.width = MAX(size.width, subviewSize.width);
            size.height += subviewSize.height;
        }
    }

    return size;
}

- (NSSize)fittingSize
{
    return self.legacyContentSize;
}

- (NSSize)intrinsicContentSize
{
    return self.legacyContentSize;
}

- (void)layoutLegacySubviews
{
    if (fLayingOutLegacySubviews)
    {
        return;
    }

    fLayingOutLegacySubviews = YES;
    fNeedsLegacyLayout = NO;

    @try
    {
        NSArray* visibleSubviews = self.visibleLegacySubviews;

        for (NSView* subview in self.views)
        {
            if ([visibleSubviews containsObject:subview])
            {
                [self attachArrangedSubviewIfNeeded:subview];
            }
            else if ([fDetachedViews containsObject:subview])
            {
                [self detachArrangedSubviewIfNeeded:subview];
            }
        }

        if (visibleSubviews.count == 0)
        {
            return;
        }

        CGFloat const spacing = self.spacing;

        if (self.orientation == TRLegacyStackViewOrientationHorizontal)
        {
            CGFloat const startOffset = fLeadingOffset;
            CGFloat fixedWidth = spacing * (visibleSubviews.count - 1);
            NSUInteger flexibleCount = 0;
            for (NSView* subview in visibleSubviews)
            {
                NSSize subviewSize = [self legacySizeForSubview:subview];
                if ([subview isKindOfClass:NSTextField.class])
                {
                    ++flexibleCount;
                }
                else
                {
                    fixedWidth += subviewSize.width;
                }
            }

            CGFloat flexibleWidth = 0.0;
            if (flexibleCount > 0)
            {
                flexibleWidth = floor(MAX(0.0, NSWidth(self.bounds) - startOffset - fixedWidth) / flexibleCount);
            }

            CGFloat offset = startOffset;
            for (NSView* subview in visibleSubviews)
            {
                NSRect frame = subview.frame;
                frame.size = [self legacySizeForSubview:subview];
                if ([subview isKindOfClass:NSTextField.class])
                {
                    frame.size.width = flexibleWidth;
                }

                frame.origin.x = offset;
                frame.origin.y = [self legacyVerticalOriginForSubviewHeight:NSHeight(frame)];
                subview.frame = frame;
                offset += NSWidth(frame) + spacing;
            }
        }
        else
        {
            CGFloat offset = NSHeight(self.bounds) - fTopOffset;
            for (NSView* subview in visibleSubviews)
            {
                NSRect frame = subview.frame;
                frame.size = [self legacySizeForSubview:subview];
                offset -= NSHeight(frame);
                frame.origin.x = [self legacyHorizontalOriginForSubviewWidth:NSWidth(frame)];
                frame.origin.y = offset;
                subview.frame = frame;
                offset -= spacing;
            }
        }
    }
    @finally
    {
        fLayingOutLegacySubviews = NO;
    }
}

- (NSMutableArray*)viewsForGravity:(TRLegacyStackViewGravity)gravity
{
    switch (gravity)
    {
    case TRLegacyStackViewGravityLeading:
        return fLeadingViews;

    case TRLegacyStackViewGravityCenter:
        return fCenterViews;

    case TRLegacyStackViewGravityTrailing:
        return fTrailingViews;
    }

    return nil;
}

- (BOOL)containsArrangedSubview:(NSView*)view
{
    return [fLeadingViews containsObject:view] || [fCenterViews containsObject:view] || [fTrailingViews containsObject:view];
}

- (void)attachArrangedSubviewIfNeeded:(NSView*)view
{
    if (view.superview == self)
    {
        return;
    }

    fUpdatingSubviews = YES;
    [self addSubview:view];
    fUpdatingSubviews = NO;
}

- (void)detachArrangedSubviewIfNeeded:(NSView*)view
{
    if (view.superview != self)
    {
        return;
    }

    fUpdatingSubviews = YES;
    [view removeFromSuperview];
    fUpdatingSubviews = NO;
}

- (void)removeArrangedSubview:(NSView*)view removeFromSuperview:(BOOL)removeFromSuperview
{
    if (view == nil)
    {
        return;
    }

    [fLeadingViews removeObject:view];
    [fCenterViews removeObject:view];
    [fTrailingViews removeObject:view];
    [fDetachedViews removeObject:view];
    [fVisibilityPriorities removeObjectForKey:[NSValue valueWithNonretainedObject:view]];

    if (removeFromSuperview && view.superview == self)
    {
        fUpdatingSubviews = YES;
        [view removeFromSuperview];
        fUpdatingSubviews = NO;
    }

    [self invalidateLegacyLayout];
}

- (void)replaceViewsInGravity:(TRLegacyStackViewGravity)gravity withViews:(NSArray*)views
{
    NSMutableArray* currentViews = [self viewsForGravity:gravity];
    if (currentViews == nil)
    {
        return;
    }

    NSArray* oldViews = [currentViews copy];
    for (NSView* oldView in oldViews)
    {
        [self removeArrangedSubview:oldView removeFromSuperview:YES];
    }

    for (NSView* view in views)
    {
        [self addView:view inGravity:gravity];
    }
}

- (CGFloat)legacyHorizontalOriginForSubviewWidth:(CGFloat)width
{
    switch (self.alignment)
    {
    case TRLegacyStackViewAlignmentRight:
    case TRLegacyStackViewAlignmentTrailing:
        return floor(NSWidth(self.bounds) + fTrailingOffset - width);

    case TRLegacyStackViewAlignmentCenterX:
        return floor((NSWidth(self.bounds) - width) / 2.0 + fCenterOffset);

    case TRLegacyStackViewAlignmentLeft:
    case TRLegacyStackViewAlignmentLeading:
    default:
        return fLeadingOffset;
    }
}

- (CGFloat)legacyVerticalOriginForSubviewHeight:(CGFloat)height
{
    switch (self.alignment)
    {
    case TRLegacyStackViewAlignmentTop:
        return floor(NSHeight(self.bounds) - fTopOffset - height);

    case TRLegacyStackViewAlignmentBottom:
        return 0.0;

    case TRLegacyStackViewAlignmentCenterY:
    default:
        return floor((NSHeight(self.bounds) - height) / 2.0);
    }
}

- (BOOL)legacyAlignmentIsVerticalCompatible:(TRLegacyStackViewAlignment)alignment
{
    switch (alignment)
    {
    case TRLegacyStackViewAlignmentTop:
    case TRLegacyStackViewAlignmentBottom:
    case TRLegacyStackViewAlignmentCenterY:
    case TRLegacyStackViewAlignmentLastBaseline:
        return NO;

    default:
        return YES;
    }
}

@end

#endif
