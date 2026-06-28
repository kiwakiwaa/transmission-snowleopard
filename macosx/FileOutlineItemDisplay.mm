// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileOutlineItemDisplay.h"

#include <libtransmission/transmission.h>

#import "NSImageAdditions.h"

static CGFloat const kImageOverlap = 1.0;

NSString* TRFileOutlineCheckTooltip(NSControlStateValue state)
{
    switch (state)
    {
    case NSControlStateValueOff:
        return NSLocalizedString(@"Don't Download", "files tab -> tooltip");
    case NSControlStateValueOn:
        return NSLocalizedString(@"Download", "files tab -> tooltip");
    case NSControlStateValueMixed:
        return NSLocalizedString(@"Download Some", "files tab -> tooltip");
    default:
        return nil;
    }
}

NSString* TRFileOutlinePriorityTooltip(NSSet* priorities)
{
    switch (priorities.count)
    {
    case 0:
        return NSLocalizedString(@"Priority Not Available", "files tab -> tooltip");
    case 1:
        switch ([[priorities anyObject] intValue])
        {
        case TR_PRI_LOW:
            return NSLocalizedString(@"Low Priority", "files tab -> tooltip");
        case TR_PRI_HIGH:
            return NSLocalizedString(@"High Priority", "files tab -> tooltip");
        case TR_PRI_NORMAL:
            return NSLocalizedString(@"Normal Priority", "files tab -> tooltip");
        default:
            return nil;
        }
    default:
        return NSLocalizedString(@"Multiple Priorities", "files tab -> tooltip");
    }
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
static NSImage* TRFileOutlinePriorityTemplateImage(NSString* imageName, NSColor* color)
{
    NSImage* image = [NSImage imageNamed:imageName];
    if (image.size.width > 0.0 && image.size.height > 0.0)
    {
        return [image imageWithColor:color];
    }

    NSImage* fallback = [[NSImage alloc] initWithSize:NSMakeSize(9.0, 12.0)];
    [fallback lockFocus];
    [color setFill];

    NSBezierPath* path = [NSBezierPath bezierPath];
    if ([imageName isEqualToString:@"PriorityHighTemplate"])
    {
        [path moveToPoint:NSMakePoint(4.5, 11.0)];
        [path lineToPoint:NSMakePoint(8.0, 6.5)];
        [path lineToPoint:NSMakePoint(5.8, 6.5)];
        [path lineToPoint:NSMakePoint(5.8, 1.0)];
        [path lineToPoint:NSMakePoint(3.2, 1.0)];
        [path lineToPoint:NSMakePoint(3.2, 6.5)];
        [path lineToPoint:NSMakePoint(1.0, 6.5)];
    }
    else if ([imageName isEqualToString:@"PriorityLowTemplate"])
    {
        [path moveToPoint:NSMakePoint(4.5, 1.0)];
        [path lineToPoint:NSMakePoint(8.0, 5.5)];
        [path lineToPoint:NSMakePoint(5.8, 5.5)];
        [path lineToPoint:NSMakePoint(5.8, 11.0)];
        [path lineToPoint:NSMakePoint(3.2, 11.0)];
        [path lineToPoint:NSMakePoint(3.2, 5.5)];
        [path lineToPoint:NSMakePoint(1.0, 5.5)];
    }
    else
    {
        [path appendBezierPathWithRect:NSMakeRect(2.0, 5.0, 5.0, 2.0)];
    }

    [path closePath];
    [path fill];
    [fallback unlockFocus];

    return fallback;
}
#endif

static NSImage* TRFileOutlinePriorityImage(NSString* imageName, NSColor* color)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
    return TRFileOutlinePriorityTemplateImage(imageName, color);
#else
    return [[NSImage imageNamed:imageName] imageWithColor:color];
#endif
}

NSArray* TRFileOutlinePriorityImages(NSSet* priorities, NSBackgroundStyle backgroundStyle)
{
    NSUInteger const count = priorities.count;
    NSMutableArray* images = [NSMutableArray arrayWithCapacity:MAX(count, 1U)];

    if (count == 0)
    {
        NSImage* image = TRFileOutlinePriorityImage(@"PriorityNormalTemplate", NSColor.lightGrayColor);
        if (image)
        {
            [images addObject:image];
        }
        return images;
    }

    NSColor* priorityColor = backgroundStyle == NSBackgroundStyleEmphasized ? NSColor.whiteColor : NSColor.darkGrayColor;
    if ([priorities containsObject:@(TR_PRI_LOW)])
    {
        NSImage* image = TRFileOutlinePriorityImage(@"PriorityLowTemplate", priorityColor);
        if (image)
        {
            [images addObject:image];
        }
    }
    if ([priorities containsObject:@(TR_PRI_NORMAL)])
    {
        NSImage* image = TRFileOutlinePriorityImage(@"PriorityNormalTemplate", priorityColor);
        if (image)
        {
            [images addObject:image];
        }
    }
    if ([priorities containsObject:@(TR_PRI_HIGH)])
    {
        NSImage* image = TRFileOutlinePriorityImage(@"PriorityHighTemplate", priorityColor);
        if (image)
        {
            [images addObject:image];
        }
    }

    return images;
}

CGFloat TRFileOutlinePriorityImageOverlap(void)
{
    return kImageOverlap;
}
