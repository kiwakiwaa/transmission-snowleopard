// PLWeakCompatibilityCore.h
// Copyright (c) 2012 Plausible Labs Cooperative, Inc.
// Used under the BSD-3-Clause license. See licenses/bsd-3-clause.txt.

#import <Foundation/Foundation.h>

// A typedef used in place of id to prevent ARC from getting its hands dirty with
// our object pointers. Even with __unsafe_unretained, ARC likes to do things like
// retain and release intermediate values, which gets us into serious trouble.
typedef void* PLObjectPtr;

#ifdef __cplusplus
extern "C" {
#endif

PLObjectPtr PLWeakCompatibilityLoadWeakRetained(PLObjectPtr* location);
PLObjectPtr PLWeakCompatibilityInitWeak(PLObjectPtr* addr, PLObjectPtr val);
void PLWeakCompatibilityDestroyWeak(PLObjectPtr* addr);
void PLWeakCompatibilityCopyWeak(PLObjectPtr* to, PLObjectPtr* from);
void PLWeakCompatibilityMoveWeak(PLObjectPtr* to, PLObjectPtr* from);
PLObjectPtr PLWeakCompatibilityLoadWeak(PLObjectPtr* location);
PLObjectPtr PLWeakCompatibilityStoreWeak(PLObjectPtr* location, PLObjectPtr obj);

// Enable or disable the use of MAZeroingWeakRef. If enabled is YES, then
// MAZeroingWeakRef is used to implement the weak functionality if present.
// If MAZWR is not present in your process, then it falls back to its simpler
// internal implementation. MAZWR use is enabled by default. Note that
// changing this value after weak references have been manipulated is
// extremely forbidden and will cause no end to havoc.
void PLWeakCompatibilitySetMAZWREnabled(BOOL enabled);

// Check whether MAZeroingWeakRef is in use. Returns YES if and only if
// MAZeroingWeakRef is present in the process and its use is not disabled
// with the above function. Returns NO if MAZWR is not present or its
// use has been explicitly disabled.
BOOL PLWeakCompatibilityHasMAZWR(void);

#ifdef __cplusplus
}
#endif
