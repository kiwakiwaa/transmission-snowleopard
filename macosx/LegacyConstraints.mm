// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyConstraints.h"

#include <libtransmission/macos-version.h>

void TRSetConstraintActive(NSLayoutConstraint* constraint, BOOL active)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    constraint.active = active;
#else
    id firstItem = [constraint firstItem];
    if (![firstItem respondsToSelector:@selector(addConstraint:)])
    {
        return;
    }

    if (active)
    {
        [firstItem addConstraint:constraint];
    }
    else
    {
        [firstItem removeConstraint:constraint];
    }
#endif
}
