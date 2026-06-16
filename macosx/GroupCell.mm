// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "GroupCell.h"
#import "CocoaCompatibility.h"

@implementation GroupCell

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9 && TR_MACOS_DEPLOYMENT_BEFORE_10_10
// Mavericks decodes this group row constraint slightly too far left compared
// with newer AppKit, leaving the color indicator visually cramped.
static CGFloat const kMavericksGroupIndicatorLeadingOffset = 5.0;

- (void)awakeFromNib
{
    [super awakeFromNib];

    for (NSLayoutConstraint* constraint in self.constraints)
    {
        if (constraint.firstItem == self.fGroupIndicatorView && constraint.firstAttribute == NSLayoutAttributeLeading &&
            constraint.secondItem == self && constraint.secondAttribute == NSLayoutAttributeLeading)
        {
            constraint.constant += kMavericksGroupIndicatorLeadingOffset;
            break;
        }
    }
}
#endif

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];

    __auto_type isEmphasized = backgroundStyle == NSBackgroundStyleEmphasized;
    self.fGroupTitleField.textColor = isEmphasized ? TRLabelColor() : TRSecondaryLabelColor();
}

@end
