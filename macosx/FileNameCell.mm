// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileNameCell.h"

#import "FileListNode.h"
#import "FileOutlineItemDisplay.h"

static CGFloat const kPaddingExpansionFrame = 2.0;

@interface FileNameCell ()

@property(nonatomic, readonly) NSMutableDictionary* fTitleAttributes;
@property(nonatomic, readonly) NSMutableDictionary* fStatusAttributes;

@end

@implementation FileNameCell

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

    copy->_fTitleAttributes = _fTitleAttributes;
    copy->_fStatusAttributes = _fStatusAttributes;

    return copy;
}

- (NSRect)imageRectForBounds:(NSRect)bounds
{
    return TRFileOutlineIconRect((FileListNode*)self.objectValue, bounds);
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
    FileListNode* node = (FileListNode*)self.objectValue;

    [node.icon drawInRect:[self imageRectForBounds:cellFrame] fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];

    self.fTitleAttributes[NSForegroundColorAttributeName] = TRFileOutlineTitleColor(node, self.backgroundStyle);
    self.fStatusAttributes[NSForegroundColorAttributeName] = TRFileOutlineStatusColor(node, self.backgroundStyle);

    NSAttributedString* titleString = [self attributedTitleForNode:node];
    NSRect titleRect = TRFileOutlineTitleRect(node, titleString, cellFrame);
    [titleString drawInRect:titleRect];

    NSAttributedString* statusString = [self attributedStatusForNode:node];
    NSRect statusRect = TRFileOutlineStatusRect(node, statusString, titleRect, cellFrame);
    [statusString drawInRect:statusRect];
}

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView*)view
{
    FileListNode* node = (FileListNode*)self.objectValue;
    NSAttributedString* titleString = [self attributedTitleForNode:node];
    NSRect realRect = TRFileOutlineTitleRect(node, titleString, cellFrame);

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
    return [[NSAttributedString alloc] initWithString:TRFileOutlineStatusString(node) attributes:self.fStatusAttributes];
}

@end
