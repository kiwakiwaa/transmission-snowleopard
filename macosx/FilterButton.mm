// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FilterButton.h"
#import "NSStringAdditions.h"

@implementation FilterButton

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize count = _count;
#endif

- (instancetype)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        _count = NSNotFound;
    }
    return self;
}

- (void)setCount:(NSUInteger)count
{
    if (count == _count)
    {
        return;
    }

    _count = count;

    self.toolTip = count == 1 ?
        NSLocalizedString(@"1 transfer", "Filter Button -> tool tip") :
        [NSString localizedStringWithFormat:NSLocalizedString(@"%lu transfers", "Filter Bar Button -> tool tip"), count];
}

@end
