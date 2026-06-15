// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileDescriptorLimit.h"

#if TR_RAISE_FILE_DESCRIPTOR_LIMIT
#include <sys/resource.h>
#endif

void TRRaiseFileDescriptorLimit(void)
{
#if TR_RAISE_FILE_DESCRIPTOR_LIMIT
    static auto constexpr DesiredFileDescriptorLimit = rlim_t{ 1024 };

    struct rlimit limit;
    if (getrlimit(RLIMIT_NOFILE, &limit) != 0 || limit.rlim_cur >= DesiredFileDescriptorLimit)
    {
        return;
    }

    rlim_t new_limit = DesiredFileDescriptorLimit;
    if (limit.rlim_max != RLIM_INFINITY && limit.rlim_max < new_limit)
    {
        new_limit = limit.rlim_max;
    }

    if (new_limit > limit.rlim_cur)
    {
        limit.rlim_cur = new_limit;
        (void)setrlimit(RLIMIT_NOFILE, &limit);
    }
#endif
}
