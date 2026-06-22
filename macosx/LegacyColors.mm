// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyColors.h"

#include <libtransmission/macos-version.h>

NSColor* TRLabelColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    return [NSColor labelColor];
#else
    return [NSColor controlTextColor];
#endif
}

NSColor* TRSecondaryLabelColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    return [NSColor secondaryLabelColor];
#else
    return [NSColor disabledControlTextColor];
#endif
}

NSColor* TRSystemRedColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemRedColor];
#else
    return [NSColor redColor];
#endif
}

NSColor* TRSystemOrangeColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemOrangeColor];
#else
    return [NSColor orangeColor];
#endif
}

NSColor* TRSystemYellowColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemYellowColor];
#else
    return [NSColor yellowColor];
#endif
}

NSColor* TRSystemGreenColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemGreenColor];
#else
    return [NSColor greenColor];
#endif
}

NSColor* TRSystemBlueColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemBlueColor];
#else
    return [NSColor blueColor];
#endif
}

NSColor* TRSystemPurpleColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemPurpleColor];
#else
    return [NSColor purpleColor];
#endif
}

NSColor* TRSystemGrayColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemGrayColor];
#else
    return [NSColor grayColor];
#endif
}

NSColor* TRSystemTealColor(void)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_12 && !TR_MACOS_SDK_BEFORE_10_12
    return [NSColor systemTealColor];
#else
    return [NSColor cyanColor];
#endif
}
