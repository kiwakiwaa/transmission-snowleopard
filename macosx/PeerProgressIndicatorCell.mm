// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "PeerProgressIndicatorCell.h"
#import "CocoaCompatibility.h"
#import "NSStringAdditions.h"

@interface PeerProgressIndicatorCell ()

@property(nonatomic, copy) NSDictionary* fAttributes;

@end

@implementation PeerProgressIndicatorCell

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize seed = _seed;
@synthesize fAttributes = _fAttributes;
#endif

- (id)copyWithZone:(NSZone*)zone
{
    PeerProgressIndicatorCell* copy = [super copyWithZone:zone];
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
    // Fragile-runtime NSCell copies bitwise-copy ARC object slots; clear copied slots before ARC stores into them.
    TRClearCopiedObjectPointer(&copy->_fAttributes);
#endif
    copy->_fAttributes = _fAttributes;

    return copy;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"DisplayPeerProgressBarNumber"])
    {
        if (!self.fAttributes)
        {
            NSMutableParagraphStyle* paragraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
            paragraphStyle.alignment = NSTextAlignmentRight;

            self.fAttributes = @{
                NSFontAttributeName : [NSFont systemFontOfSize:11.0],
                NSForegroundColorAttributeName : TRLabelColor(),
                NSParagraphStyleAttributeName : paragraphStyle
            };
        }

        [[NSString percentString:self.floatValue longDecimals:NO] drawInRect:cellFrame withAttributes:self.fAttributes];
    }
    else
    {
        //attributes not needed anymore
        if (self.fAttributes)
        {
            self.fAttributes = nil;
        }

        [super drawWithFrame:cellFrame inView:controlView];
        if (self.seed)
        {
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
            NSBezierPath* check = [NSBezierPath bezierPath];
            check.lineWidth = 1.5;
            [check setLineCapStyle:NSRoundLineCapStyle];
            [check setLineJoinStyle:NSRoundLineJoinStyle];

            CGFloat const width = MIN(8.0, NSWidth(cellFrame) - 4.0);
            CGFloat const height = MIN(6.0, NSHeight(cellFrame) - 4.0);
            CGFloat const minX = floor(NSMidX(cellFrame) - width * 0.5);
            CGFloat const minY = floor(NSMidY(cellFrame) - height * 0.5);

            [check moveToPoint:NSMakePoint(minX, minY + height * 0.45)];
            [check lineToPoint:NSMakePoint(minX + width * 0.38, minY)];
            [check lineToPoint:NSMakePoint(minX + width, minY + height)];

            [[NSColor whiteColor] setStroke];
            [check stroke];
#else
            NSImage* checkImage = [NSImage imageNamed:@"CompleteCheck"];

            NSSize const imageSize = checkImage.size;
            NSRect const rect = NSMakeRect(
                floor(NSMidX(cellFrame) - imageSize.width * 0.5),
                floor(NSMidY(cellFrame) - imageSize.height * 0.5),
                imageSize.width,
                imageSize.height);

            [checkImage drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0
                    respectFlipped:YES
                             hints:nil];
#endif
        }
    }
}

@end
