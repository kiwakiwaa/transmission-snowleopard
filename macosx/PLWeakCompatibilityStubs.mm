// PLWeakCompatibilityStubs.mm
// Copyright (c) 2012 Plausible Labs Cooperative, Inc.
// Used under the BSD-3-Clause license. See licenses/bsd-3-clause.txt.

#import "PLWeakCompatibilityStubs.h"

#import <dlfcn.h>

// Convenience for falling through to the system implementation.
static BOOL fallthroughEnabled = YES;

#define NEXT(name, ...) \
    do \
    { \
        static dispatch_once_t fptrOnce; \
        static __typeof__(&name) fptr; \
        dispatch_once(&fptrOnce, ^{ \
            fptr = (__typeof__(fptr))dlsym(RTLD_NEXT, #name); \
        }); \
        if (fallthroughEnabled && fptr != NULL) \
        { \
            return fptr(__VA_ARGS__); \
        } \
    } while (0)

void PLWeakCompatibilitySetFallthroughEnabled(BOOL enabled)
{
    fallthroughEnabled = enabled;
}

PLObjectPtr objc_loadWeakRetained(PLObjectPtr* location)
{
    NEXT(objc_loadWeakRetained, location);

    return PLWeakCompatibilityLoadWeakRetained(location);
}

PLObjectPtr objc_initWeak(PLObjectPtr* addr, PLObjectPtr val)
{
    NEXT(objc_initWeak, addr, val);

    return PLWeakCompatibilityInitWeak(addr, val);
}

void objc_destroyWeak(PLObjectPtr* addr)
{
    NEXT(objc_destroyWeak, addr);

    PLWeakCompatibilityDestroyWeak(addr);
}

void objc_copyWeak(PLObjectPtr* to, PLObjectPtr* from)
{
    NEXT(objc_copyWeak, to, from);

    PLWeakCompatibilityCopyWeak(to, from);
}

void objc_moveWeak(PLObjectPtr* to, PLObjectPtr* from)
{
    NEXT(objc_moveWeak, to, from);

    PLWeakCompatibilityMoveWeak(to, from);
}

PLObjectPtr objc_loadWeak(PLObjectPtr* location)
{
    NEXT(objc_loadWeak, location);

    return PLWeakCompatibilityLoadWeak(location);
}

PLObjectPtr objc_storeWeak(PLObjectPtr* location, PLObjectPtr obj)
{
    NEXT(objc_storeWeak, location, obj);

    return PLWeakCompatibilityStoreWeak(location, obj);
}
