// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileNameCell.h"

#include <libtransmission/macos-version.h>

#import "FileListNode.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

static CGFloat const kPaddingExpansionFrame = 2.0;
static CGFloat const kPaddingHorizontal = 2.0;
static CGFloat const kImageFolderSize = 16.0;
static CGFloat const kImageIconSize = 32.0;
static CGFloat const kPaddingBetweenImageAndTitle = 4.0;
static CGFloat const kPaddingAboveTitleFile = 2.0;
static CGFloat const kPaddingBelowStatusFile = 2.0;
static CGFloat const kPaddingBetweenNameAndFolderStatus = 4.0;

static CGFloat TRFileNameCellIconSize(FileListNode* node)
{
    return node.isFolder ? kImageFolderSize : kImageIconSize;
}

static NSRect TRFileNameCellIconRect(FileListNode* node, NSRect bounds)
{
    CGFloat const imageSize = TRFileNameCellIconSize(node);
    CGFloat const iconX = NSMinX(bounds) + kPaddingHorizontal + (kImageIconSize - imageSize) / 2.0;
    CGFloat const iconY = NSMidY(bounds) - imageSize / 2.0;

    return NSMakeRect(iconX, iconY, imageSize, imageSize);
}

static CGFloat TRFileNameCellTextOriginX(NSRect bounds)
{
    return NSMinX(bounds) + kPaddingHorizontal + kImageIconSize + kPaddingBetweenImageAndTitle;
}

static NSRect TRFileNameCellTitleRect(FileListNode* node, NSAttributedString* title, NSRect bounds)
{
    NSSize const titleSize = title.size;
    CGFloat const textX = TRFileNameCellTextOriginX(bounds);

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

static NSRect TRFileNameCellStatusRect(FileListNode* node, NSAttributedString* status, NSRect titleRect, NSRect bounds)
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

static NSString* TRFileNameCellStatusString(FileListNode* node)
{
    Torrent* torrent = node.torrent;
    CGFloat const progress = [torrent fileProgress:node];
    NSString* percentString = [NSString percentString:progress longDecimals:YES];

    return [NSString stringWithFormat:NSLocalizedString(@"%@ of %@", "Inspector -> Files tab -> file status string"),
                                      percentString,
                                      [NSString stringForFileSize:node.size]];
}

static NSColor* TRFileNameCellTitleColor(FileListNode* node, NSBackgroundStyle backgroundStyle)
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

static NSColor* TRFileNameCellStatusColor(FileListNode* node, NSBackgroundStyle backgroundStyle)
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

@interface FileNameCell ()

@property(nonatomic, readonly) NSMutableDictionary* fTitleAttributes;
@property(nonatomic, readonly) NSMutableDictionary* fStatusAttributes;

@end

@implementation FileNameCell

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fTitleAttributes = _fTitleAttributes;
@synthesize fStatusAttributes = _fStatusAttributes;
#endif

- (instancetype)init
{
    if ((self = [super init]))
    {
        NSMutableParagraphStyle* paragraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
        paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;

        _fTitleAttributes = [[NSMutableDictionary alloc]
            initWithObjectsAndKeys:[NSFont messageFontOfSize:12.0], NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];

        NSMutableParagraphStyle* statusParagraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
        statusParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;

        _fStatusAttributes = [[NSMutableDictionary alloc]
            initWithObjectsAndKeys:[NSFont messageFontOfSize:9.0], NSFontAttributeName, statusParagraphStyle, NSParagraphStyleAttributeName, nil];
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    FileNameCell* copy = [super copyWithZone:zone];

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
    // Fragile-runtime NSCell copies bitwise-copy ARC object slots; clear copied slots before ARC stores into them.
    TRClearCopiedObjectPointer(&copy->_fTitleAttributes);
    TRClearCopiedObjectPointer(&copy->_fStatusAttributes);
#endif
    copy->_fTitleAttributes = _fTitleAttributes;
    copy->_fStatusAttributes = _fStatusAttributes;

    return copy;
}

- (NSRect)imageRectForBounds:(NSRect)bounds
{
    return TRFileNameCellIconRect((FileListNode*)self.objectValue, bounds);
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
    FileListNode* node = (FileListNode*)self.objectValue;

    [node.icon drawInRect:[self imageRectForBounds:cellFrame] fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];

    self.fTitleAttributes[NSForegroundColorAttributeName] = TRFileNameCellTitleColor(node, self.backgroundStyle);
    self.fStatusAttributes[NSForegroundColorAttributeName] = TRFileNameCellStatusColor(node, self.backgroundStyle);

    NSAttributedString* titleString = [self attributedTitleForNode:node];
    NSRect titleRect = TRFileNameCellTitleRect(node, titleString, cellFrame);
    [titleString drawInRect:titleRect];

    NSAttributedString* statusString = [self attributedStatusForNode:node];
    NSRect statusRect = TRFileNameCellStatusRect(node, statusString, titleRect, cellFrame);
    [statusString drawInRect:statusRect];
}

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView*)view
{
    FileListNode* node = (FileListNode*)self.objectValue;
    NSAttributedString* titleString = [self attributedTitleForNode:node];
    NSRect realRect = TRFileNameCellTitleRect(node, titleString, cellFrame);

    if (titleString.size.width > NSWidth(realRect) &&
        NSMouseInRect([view convertPoint:view.window.mouseLocationOutsideOfEventStream fromView:nil], realRect, [view isFlipped]))
    {
        realRect.size.width = titleString.size.width;
        return NSInsetRect(realRect, -kPaddingExpansionFrame, -kPaddingExpansionFrame);
    }

    return NSZeroRect;
}

- (void)drawWithExpansionFrame:(NSRect)cellFrame inView:(NSView*)view
{
    FileListNode* node = (FileListNode*)self.objectValue;
    cellFrame.origin.x += kPaddingExpansionFrame;
    cellFrame.origin.y += kPaddingExpansionFrame;

    self.fTitleAttributes[NSForegroundColorAttributeName] = NSColor.controlTextColor;
    [[self attributedTitleForNode:node] drawInRect:cellFrame];
}

- (NSAttributedString*)attributedTitleForNode:(FileListNode*)node
{
    return [[NSAttributedString alloc] initWithString:node.name attributes:self.fTitleAttributes];
}

- (NSAttributedString*)attributedStatusForNode:(FileListNode*)node
{
    return [[NSAttributedString alloc] initWithString:TRFileNameCellStatusString(node) attributes:self.fStatusAttributes];
}

@end
