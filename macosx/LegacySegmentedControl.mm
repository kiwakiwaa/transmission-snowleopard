// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacySegmentedControl.h"

#include <libtransmission/macos-version.h>

void TRSetSegmentTag(NSSegmentedControl* control, NSInteger tag, NSInteger segment)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    [control setTag:tag forSegment:segment];
#else
    (void)control;
    (void)tag;
    (void)segment;
#endif
}

NSInteger TRSelectedSegmentTag(NSSegmentedControl* control)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    return [control selectedTag];
#else
    return [control selectedSegment];
#endif
}

void TRSetSegmentToolTip(NSSegmentedControl* control, NSString* toolTip, NSInteger segment)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    [control setToolTip:toolTip forSegment:segment];
#else
    (void)segment;
    [control setToolTip:toolTip];
#endif
}
