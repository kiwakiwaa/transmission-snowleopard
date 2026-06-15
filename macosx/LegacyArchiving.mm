// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyArchiving.h"

#include <libtransmission/macos-version.h>

NSData* TRArchivedDataForObject(id object)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    return [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:nil];
#else
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#endif
}

id TRUnarchiveObjectFromData(NSData* data, NSSet* allowedClasses)
{
    if (data == nil)
    {
        return nil;
    }

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    return [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses fromData:data error:nil];
#else
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#endif
}

id TRUnarchiveLegacyObjectFromData(NSData* data)
{
    if (data == nil)
    {
        return nil;
    }

    // Transmission 3 used NSArchiver for a few defaults; NSUnarchiver is the only compatible migration path.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}
