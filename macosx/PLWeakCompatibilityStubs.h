// PLWeakCompatibilityStubs.h
// Copyright (c) 2012 Plausible Labs Cooperative, Inc.
// Used under the BSD-3-Clause license. See licenses/bsd-3-clause.txt.

#import <Foundation/Foundation.h>

#import "PLWeakCompatibilityCore.h"

#ifdef __cplusplus
extern "C" {
#endif

// These are prototypes of the various runtime functions the compiler calls to handle
// __weak variables. If you import this header and these prototypes interfere with
// the official ones (due to using PLObjectPtr instead of id), simply do
// #define EXCLUDE_STUB_PROTOTYPES 1 immediately before the import statement to
// exclude these.
#if !EXCLUDE_STUB_PROTOTYPES
PLObjectPtr objc_loadWeakRetained(PLObjectPtr *location);
PLObjectPtr objc_initWeak(PLObjectPtr *addr, PLObjectPtr val);
void objc_destroyWeak(PLObjectPtr *addr);
void objc_copyWeak(PLObjectPtr *to, PLObjectPtr *from);
void objc_moveWeak(PLObjectPtr *to, PLObjectPtr *from);
PLObjectPtr objc_loadWeak(PLObjectPtr *location);
PLObjectPtr objc_storeWeak(PLObjectPtr *location, PLObjectPtr obj);
#endif

// Enable or disable the use of native fallthroughs to built-in runtime functions
// when present. When enabled, if the necessary weak reference functions are
// present in the Objective-C runtime, they are called instead of the third-party
// weak reference implementation. When disabled, the third-party implementation
// is always used. This is enabled by default, and should not be disabled except
// for testing purposes. Do not change this value after weak references have been
// manipulated, or you will severely regret it.
void PLWeakCompatibilitySetFallthroughEnabled(BOOL enabled);

#ifdef __cplusplus
}
#endif
