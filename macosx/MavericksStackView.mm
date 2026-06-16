// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "MavericksStackView.h"

#import <float.h>
#import <math.h>

@implementation MavericksStackView

- (void)awakeFromNib
{
    [super awakeFromNib];

    // Mavericks uses real NSStackView, but its ibtool cannot compile the modern
    // <stackView> XIB nodes. The curated Mavericks XIBs decode those nodes as a
    // plain custom view, so rebuild the native stack-view properties from the
    // archived frames.
    NSArray* subviews = [self mavericksDecodedSubviews];
    self.orientation = [self mavericksInferredOrientationForViews:subviews];
    self.alignment = [self mavericksInferredAlignmentForViews:subviews orientation:self.orientation];
    self.spacing = [self mavericksInferredSpacingForViews:subviews orientation:self.orientation];
    [self setViews:subviews inGravity:NSStackViewGravityCenter];
}

- (NSArray*)mavericksDecodedSubviews
{
    NSMutableArray* views = [NSMutableArray array];
    for (NSView* subview in self.subviews)
    {
        if (![NSStringFromClass(subview.class) isEqualToString:@"NSStackViewSpacer"])
        {
            [views addObject:subview];
        }
    }
    return views;
}

- (NSUserInterfaceLayoutOrientation)mavericksInferredOrientationForViews:(NSArray*)views
{
    if (views.count < 2)
    {
        return NSWidth(self.bounds) >= NSHeight(self.bounds) ? NSUserInterfaceLayoutOrientationHorizontal :
                                                              NSUserInterfaceLayoutOrientationVertical;
    }

    CGFloat minX = CGFLOAT_MAX;
    CGFloat maxX = -CGFLOAT_MAX;
    CGFloat minY = CGFLOAT_MAX;
    CGFloat maxY = -CGFLOAT_MAX;
    for (NSView* view in views)
    {
        NSRect frame = view.frame;
        CGFloat centerX = NSMidX(frame);
        CGFloat centerY = NSMidY(frame);
        minX = MIN(minX, centerX);
        maxX = MAX(maxX, centerX);
        minY = MIN(minY, centerY);
        maxY = MAX(maxY, centerY);
    }

    return (maxY - minY) > (maxX - minX) ? NSUserInterfaceLayoutOrientationVertical :
                                           NSUserInterfaceLayoutOrientationHorizontal;
}

- (NSLayoutAttribute)mavericksInferredAlignmentForViews:(NSArray*)views
                                            orientation:(NSUserInterfaceLayoutOrientation)orientation
{
    if (views.count < 2)
    {
        return orientation == NSUserInterfaceLayoutOrientationVertical ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    }

    CGFloat const tolerance = 1.0;
    NSView* firstView = [views objectAtIndex:0];
    CGFloat firstMin = orientation == NSUserInterfaceLayoutOrientationVertical ? NSMinX(firstView.frame) : NSMinY(firstView.frame);
    CGFloat firstMax = orientation == NSUserInterfaceLayoutOrientationVertical ? NSMaxX(firstView.frame) : NSMaxY(firstView.frame);
    CGFloat firstCenter = orientation == NSUserInterfaceLayoutOrientationVertical ? NSMidX(firstView.frame) : NSMidY(firstView.frame);
    BOOL sameMin = YES;
    BOOL sameMax = YES;
    BOOL sameCenter = YES;

    for (NSView* view in views)
    {
        NSRect frame = view.frame;
        CGFloat min = orientation == NSUserInterfaceLayoutOrientationVertical ? NSMinX(frame) : NSMinY(frame);
        CGFloat max = orientation == NSUserInterfaceLayoutOrientationVertical ? NSMaxX(frame) : NSMaxY(frame);
        CGFloat center = orientation == NSUserInterfaceLayoutOrientationVertical ? NSMidX(frame) : NSMidY(frame);
        sameMin = sameMin && fabs(min - firstMin) <= tolerance;
        sameMax = sameMax && fabs(max - firstMax) <= tolerance;
        sameCenter = sameCenter && fabs(center - firstCenter) <= tolerance;
    }

    if (orientation == NSUserInterfaceLayoutOrientationVertical)
    {
        if (sameMax)
        {
            return NSLayoutAttributeTrailing;
        }
        if (sameCenter)
        {
            return NSLayoutAttributeCenterX;
        }
        return NSLayoutAttributeLeading;
    }

    if (sameCenter)
    {
        return NSLayoutAttributeCenterY;
    }
    if (sameMax)
    {
        return NSLayoutAttributeBottom;
    }
    return NSLayoutAttributeTop;
}

- (CGFloat)mavericksInferredSpacingForViews:(NSArray*)views orientation:(NSUserInterfaceLayoutOrientation)orientation
{
    if (views.count < 2)
    {
        return 8.0;
    }

    NSArray* sortedViews = [views sortedArrayUsingComparator:^NSComparisonResult(NSView* a, NSView* b) {
        if (orientation == NSUserInterfaceLayoutOrientationVertical)
        {
            CGFloat ay = NSMinY(a.frame);
            CGFloat by = NSMinY(b.frame);
            return ay > by ? NSOrderedAscending : (ay < by ? NSOrderedDescending : NSOrderedSame);
        }

        CGFloat ax = NSMinX(a.frame);
        CGFloat bx = NSMinX(b.frame);
        return ax < bx ? NSOrderedAscending : (ax > bx ? NSOrderedDescending : NSOrderedSame);
    }];

    CGFloat total = 0.0;
    NSUInteger count = 0;
    for (NSUInteger i = 1; i < sortedViews.count; ++i)
    {
        NSView* previous = [sortedViews objectAtIndex:i - 1];
        NSView* current = [sortedViews objectAtIndex:i];
        CGFloat gap = orientation == NSUserInterfaceLayoutOrientationVertical ?
            NSMinY(previous.frame) - NSMaxY(current.frame) :
            NSMinX(current.frame) - NSMaxX(previous.frame);
        if (gap >= 0.0)
        {
            total += gap;
            ++count;
        }
    }

    return count > 0 ? round(total / count) : 8.0;
}

@end
