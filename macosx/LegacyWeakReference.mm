// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyWeakReference.h"

#import "PLWeakCompatibilityCore.h"

@implementation LegacyWeakReference
{
    PLObjectPtr _object;
}

- (instancetype)initWithObject:(id)object
{
    if ((self = [super init]))
    {
        PLWeakCompatibilityInitWeak(&_object, (__bridge PLObjectPtr)object);
    }

    return self;
}

- (void)dealloc
{
    PLWeakCompatibilityDestroyWeak(&_object);
}

- (id)object
{
    return (__bridge_transfer id)PLWeakCompatibilityLoadWeakRetained(&_object);
}

@end
