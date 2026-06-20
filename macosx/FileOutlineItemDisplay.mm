// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileOutlineItemDisplay.h"

#include <libtransmission/transmission.h>

#import "FileListNode.h"
#import "NSImageAdditions.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

static CGFloat const kPaddingHorizontal = 2.0;
static CGFloat const kImageFolderSize = 16.0;
static CGFloat const kImageIconSize = 32.0;
static CGFloat const kPaddingBetweenImageAndTitle = 4.0;
static CGFloat const kPaddingAboveTitleFile = 2.0;
static CGFloat const kPaddingBelowStatusFile = 2.0;
static CGFloat const kPaddingBetweenNameAndFolderStatus = 4.0;
static CGFloat const kImageOverlap = 1.0;

CGFloat TRFileOutlineIconSize(FileListNode* node)
{
    return node.isFolder ? kImageFolderSize : kImageIconSize;
}

NSRect TRFileOutlineIconRect(FileListNode* node, NSRect bounds)
{
    CGFloat const imageSize = TRFileOutlineIconSize(node);
    CGFloat const iconSlot = kImageIconSize;
    CGFloat const iconX = NSMinX(bounds) + kPaddingHorizontal + (iconSlot - imageSize) / 2.0;
    CGFloat const iconY = NSMidY(bounds) - imageSize / 2.0;

    return NSMakeRect(iconX, iconY, imageSize, imageSize);
}

CGFloat TRFileOutlineTextOriginX(FileListNode* node, NSRect bounds)
{
    (void)node;
    return NSMinX(bounds) + kPaddingHorizontal + kImageIconSize + kPaddingBetweenImageAndTitle;
}

NSRect TRFileOutlineTitleRect(FileListNode* node, NSAttributedString* title, NSRect bounds)
{
    NSSize const titleSize = title.size;
    CGFloat const textX = TRFileOutlineTextOriginX(node, bounds);

    NSRect result;
    if (!node.isFolder)
    {
        result.origin.x = textX;
        result.origin.y = NSMinY(bounds) + kPaddingAboveTitleFile;
        result.size.width = MAX(0.0, NSMaxX(bounds) - textX);
    }
    else
    {
        result.origin.x = textX;
        result.origin.y = NSMidY(bounds) - titleSize.height * 0.5;
        result.size.width = MIN(titleSize.width, MAX(0.0, NSMaxX(bounds) - textX));
    }
    result.size.height = titleSize.height;

    return result;
}

NSRect TRFileOutlineStatusRect(FileListNode* node, NSAttributedString* status, NSRect titleRect, NSRect bounds)
{
    NSSize const statusSize = status.size;

    NSRect result;
    if (!node.isFolder)
    {
        result.origin.x = NSMinX(titleRect);
        result.origin.y = NSMaxY(bounds) - kPaddingBelowStatusFile - statusSize.height;
        result.size.width = NSWidth(titleRect);
    }
    else
    {
        result.origin.x = NSMaxX(titleRect) + kPaddingBetweenNameAndFolderStatus;
        result.origin.y = NSMaxY(titleRect) - statusSize.height - 1.0;
        result.size.width = MAX(0.0, NSMaxX(bounds) - NSMinX(result));
    }
    result.size.height = statusSize.height;

    return result;
}

NSString* TRFileOutlineStatusString(FileListNode* node)
{
    Torrent* torrent = node.torrent;
    CGFloat const progress = [torrent fileProgress:node];
    NSString* percentString = [NSString percentString:progress longDecimals:YES];

    return [NSString stringWithFormat:NSLocalizedString(@"%@ of %@", "Inspector -> Files tab -> file status string"),
                                      percentString,
                                      [NSString stringForFileSize:node.size]];
}

NSString* TRFileOutlinePathTooltip(FileListNode* node)
{
    NSString* path = [node.torrent fileLocation:node];
    if (!path)
    {
        path = [node.path stringByAppendingPathComponent:node.name];
    }
    return path;
}

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

NSColor* TRFileOutlineTitleColor(FileListNode* node, NSBackgroundStyle backgroundStyle)
{
    if (backgroundStyle == NSBackgroundStyleEmphasized)
    {
        return NSColor.whiteColor;
    }
    if ([node.torrent checkForFiles:node.indexes] == NSControlStateValueOff)
    {
        return NSColor.disabledControlTextColor;
    }

    return NSColor.controlTextColor;
}

NSColor* TRFileOutlineStatusColor(FileListNode* node, NSBackgroundStyle backgroundStyle)
{
    if (backgroundStyle == NSBackgroundStyleEmphasized)
    {
        return NSColor.whiteColor;
    }
    if ([node.torrent checkForFiles:node.indexes] == NSControlStateValueOff)
    {
        return NSColor.disabledControlTextColor;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
    return NSColor.disabledControlTextColor;
#else
    return NSColor.secondaryLabelColor;
#endif
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
