// PLWeakCompatibilityCore.mm
// Copyright (c) 2012 Plausible Labs Cooperative, Inc.
// Used under the BSD-3-Clause license. See licenses/bsd-3-clause.txt.

#import "PLWeakCompatibilityCore.h"

#import <pthread.h>

// We need our own prototypes for some functions to avoid conflicts, so disable
// the ones from the runtime header while importing it.
#define object_getClass object_getClass_disabled_for_ARC_PLWeakCompatibilityCore
#define objc_loadWeak objc_loadWeak_disabled_for_ARC_PLWeakCompatibilityCore
#define objc_storeWeak objc_storeWeak_disabled_for_ARC_PLWeakCompatibilityCore
// Note to future self: associated objects are basically incompatible with older
// OSes due to failed cleanup with isa-swizzled objects. So, don't try to use
// them. Thanks, past self.
#import <objc/runtime.h>
#undef object_getClass
#undef objc_loadWeak
#undef objc_storeWeak

// MAZeroingWeakRef Support
static Class MAZWR = Nil;
static bool mazwrEnabled = true;
static inline bool has_mazwr()
{
    if (!mazwrEnabled)
    {
        return false;
    }

    static dispatch_once_t lookup_once = 0;
    dispatch_once(&lookup_once, ^{
        MAZWR = NSClassFromString(@"MAZeroingWeakRef");
    });

    return MAZWR != nil;
}

// Minimal MAZWR API that we rely on
@interface MAZeroingWeakRef : NSObject
- (id)initWithTarget:(PLObjectPtr)target;
- (PLObjectPtr)target;
@end

void PLWeakCompatibilitySetMAZWREnabled(BOOL enabled)
{
    mazwrEnabled = enabled;
}

BOOL PLWeakCompatibilityHasMAZWR(void)
{
    return has_mazwr();
}

// Runtime (or ARC compatibility) prototypes we use here.
extern "C" {
PLObjectPtr objc_release(PLObjectPtr obj);
PLObjectPtr objc_autorelease(PLObjectPtr obj);
PLObjectPtr objc_retain(PLObjectPtr obj);
Class object_getClass(PLObjectPtr obj);
}

// This mutex protects all shared state
static pthread_mutex_t gWeakMutex;

// A map from objects to CFMutableSets containing weak addresses
static CFMutableDictionaryRef gObjectToAddressesMap;

// A list of all classes that have been swizzled
static CFMutableSetRef gSwizzledClasses;

// A list of all objects that are in the middle of being released
static CFMutableBagRef gReleasingObjects;

// Condition variable used to signal when releasing objects are done releasing
static pthread_cond_t gReleasingObjectsCond;

// Thread local storage key
static pthread_key_t gTLSKey;

// Thread local storage struct
struct TLS
{
    // Tables tracking the last class a swizzled method was sent to on an object
    CFMutableDictionaryRef lastReleaseClassTable;
    CFMutableDictionaryRef lastDeallocClassTable;
};

// Ensure everything is properly initialized
static void WeakInit(void);

// Fetch the TLS struct for this thread
static struct TLS* GetTLS(void);

// Destroy the thread's TLS struct
static void DestroyTLS(void* ptr);

// Make sure the object's class is properly swizzled to clear weak refs on deallocation
static void EnsureDeallocationTrigger(PLObjectPtr obj);

// Selectors, for convenience and to work around ARC paranoia re: @selector(release) etc.
static SEL releaseSEL;
static SEL releaseSELSwizzled;
static SEL deallocSEL;
static SEL deallocSELSwizzled;

PLObjectPtr PLWeakCompatibilityLoadWeakRetained(PLObjectPtr* location)
{
    /* Hand off to MAZWR */
    if (has_mazwr())
    {
        MAZeroingWeakRef* mazrw = (__bridge MAZeroingWeakRef*)*location;
        return objc_retain([mazrw target]);
    }

    WeakInit();

    PLObjectPtr obj;
    pthread_mutex_lock(&gWeakMutex);
    {
        obj = *location;
        while (CFBagContainsValue(gReleasingObjects, obj))
        {
            pthread_cond_wait(&gReleasingObjectsCond, &gWeakMutex);
            obj = *location;
        }
        objc_retain(obj);
    }
    pthread_mutex_unlock(&gWeakMutex);

    return obj;
}

PLObjectPtr PLWeakCompatibilityInitWeak(PLObjectPtr* addr, PLObjectPtr val)
{
    *addr = NULL;
    return PLWeakCompatibilityStoreWeak(addr, val);
}

void PLWeakCompatibilityDestroyWeak(PLObjectPtr* addr)
{
    PLWeakCompatibilityStoreWeak(addr, NULL);
}

void PLWeakCompatibilityCopyWeak(PLObjectPtr* to, PLObjectPtr* from)
{
    PLWeakCompatibilityInitWeak(to, PLWeakCompatibilityLoadWeak(from));
}

void PLWeakCompatibilityMoveWeak(PLObjectPtr* to, PLObjectPtr* from)
{
    PLWeakCompatibilityCopyWeak(to, from);
    PLWeakCompatibilityDestroyWeak(from);
}

PLObjectPtr PLWeakCompatibilityLoadWeak(PLObjectPtr* location)
{
    return objc_autorelease(PLWeakCompatibilityLoadWeakRetained(location));
}

PLObjectPtr PLWeakCompatibilityStoreWeak(PLObjectPtr* location, PLObjectPtr obj)
{
    /* Hand off to MAZWR */
    if (has_mazwr())
    {
        if (*location != nil)
        {
            objc_release(*location);
        }

        if (obj != nil)
        {
            MAZeroingWeakRef* ref = [[MAZWR alloc] initWithTarget:obj];
            *location = (__bridge_retained PLObjectPtr)ref;
        }
        else
        {
            *location = NULL;
        }

        return obj;
    }

    WeakInit();

    pthread_mutex_lock(&gWeakMutex);
    {
        CFMutableSetRef addresses = (CFMutableSetRef)CFDictionaryGetValue(gObjectToAddressesMap, *location);
        if (addresses != NULL)
        {
            CFSetRemoveValue(addresses, location);
        }

        *location = obj;

        if (obj != nil)
        {
            addresses = (CFMutableSetRef)CFDictionaryGetValue(gObjectToAddressesMap, obj);

            if (addresses == NULL)
            {
                addresses = CFSetCreateMutable(NULL, 0, NULL);
                CFDictionarySetValue(gObjectToAddressesMap, obj, addresses);
                CFRelease(addresses);
            }

            CFSetAddValue(addresses, location);

            EnsureDeallocationTrigger(obj);
        }
    }
    pthread_mutex_unlock(&gWeakMutex);

    return obj;
}

static void WeakInit(void)
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);

        pthread_mutex_init(&gWeakMutex, &attr);

        pthread_mutexattr_destroy(&attr);

        gObjectToAddressesMap = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);

        gSwizzledClasses = CFSetCreateMutable(NULL, 0, NULL);

        gReleasingObjects = CFBagCreateMutable(NULL, 0, NULL);
        pthread_cond_init(&gReleasingObjectsCond, NULL);

        int err = pthread_key_create(&gTLSKey, DestroyTLS);
        if (err != 0)
        {
            NSLog(@"Error calling pthread_key_create, we really can't recover from that: %s (%d)", strerror(err), err);
            abort();
        }

        releaseSEL = sel_getUid("release");
        releaseSELSwizzled = sel_getUid("release_PLWeakCompatibility_swizzled");
        deallocSEL = sel_getUid("dealloc");
        deallocSELSwizzled = sel_getUid("dealloc_PLWeakCompatibility_swizzled");
    });
}

static struct TLS* GetTLS(void)
{
    struct TLS* tls = (struct TLS*)pthread_getspecific(gTLSKey);
    if (tls == NULL)
    {
        tls = (struct TLS*)calloc(1, sizeof(*tls));
        tls->lastReleaseClassTable = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        tls->lastDeallocClassTable = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        pthread_setspecific(gTLSKey, tls);
    }
    return tls;
}

static void DestroyTLS(void* ptr)
{
    struct TLS* tls = (struct TLS*)ptr;
    if (tls != NULL && tls->lastReleaseClassTable)
    {
        CFRelease(tls->lastReleaseClassTable);
        CFRelease(tls->lastDeallocClassTable);
    }
    free(tls);
}

static Class TopClassImplementingMethod(Class start, SEL sel)
{
    IMP imp = class_getMethodImplementation(start, sel);

    Class previous = start;
    Class cursor = class_getSuperclass(previous);
    while (cursor != Nil)
    {
        if (imp != class_getMethodImplementation(cursor, sel))
        {
            break;
        }
        previous = cursor;
        cursor = class_getSuperclass(cursor);
    }

    return previous;
}

static void SwizzledReleaseIMP(PLObjectPtr self, SEL _cmd)
{
    struct TLS* tls = GetTLS();

    pthread_mutex_lock(&gWeakMutex);
    {
        CFBagAddValue(gReleasingObjects, self);
    }
    pthread_mutex_unlock(&gWeakMutex);

    Class lastSent = (__bridge Class)CFDictionaryGetValue(tls->lastReleaseClassTable, self);
    Class targetClass = lastSent == Nil ? object_getClass(self) : class_getSuperclass(lastSent);
    targetClass = TopClassImplementingMethod(targetClass, releaseSELSwizzled);

    if (!class_respondsToSelector(targetClass, releaseSELSwizzled))
    {
        targetClass = object_getClass(self);
        targetClass = TopClassImplementingMethod(targetClass, releaseSELSwizzled);
    }

    CFDictionarySetValue(tls->lastReleaseClassTable, self, (__bridge void*)targetClass);

    void (*origIMP)(PLObjectPtr, SEL) = (__typeof__(origIMP))class_getMethodImplementation(targetClass, releaseSELSwizzled);
    origIMP(self, _cmd);

    CFDictionaryRemoveValue(tls->lastReleaseClassTable, self);

    pthread_mutex_lock(&gWeakMutex);
    {
        CFBagRemoveValue(gReleasingObjects, self);
        pthread_cond_broadcast(&gReleasingObjectsCond);
    }
    pthread_mutex_unlock(&gWeakMutex);
}

static void ClearAddress(const void* value, void* context)
{
    (void)context;

    void** address = (void**)value;
    *address = NULL;
}

static void SwizzledDeallocIMP(PLObjectPtr self, SEL _cmd)
{
    struct TLS* tls = GetTLS();

    pthread_mutex_lock(&gWeakMutex);
    {
        CFSetRef addresses = (CFSetRef)CFDictionaryGetValue(gObjectToAddressesMap, self);
        if (addresses != NULL)
        {
            CFSetApplyFunction(addresses, ClearAddress, NULL);
        }
        CFDictionaryRemoveValue(gObjectToAddressesMap, self);

        pthread_cond_broadcast(&gReleasingObjectsCond);
    }
    pthread_mutex_unlock(&gWeakMutex);

    Class lastSent = (__bridge Class)CFDictionaryGetValue(tls->lastDeallocClassTable, self);
    Class targetClass = lastSent == Nil ? object_getClass(self) : class_getSuperclass(lastSent);
    targetClass = TopClassImplementingMethod(targetClass, deallocSELSwizzled);
    CFDictionarySetValue(tls->lastDeallocClassTable, self, (__bridge void*)targetClass);

    void (*origIMP)(PLObjectPtr, SEL) = (__typeof__(origIMP))class_getMethodImplementation(targetClass, deallocSELSwizzled);
    origIMP(self, _cmd);

    CFDictionaryRemoveValue(tls->lastDeallocClassTable, self);
}

static void Swizzle(Class c, SEL orig, SEL newSel, IMP newIMP)
{
    Method m = class_getInstanceMethod(c, orig);
    IMP origIMP = method_getImplementation(m);
    class_addMethod(c, newSel, origIMP, method_getTypeEncoding(m));
    class_replaceMethod(c, orig, newIMP, method_getTypeEncoding(m));
}

static void EnsureDeallocationTrigger(PLObjectPtr obj)
{
    Class c = object_getClass(obj);
    if (CFSetContainsValue(gSwizzledClasses, (__bridge const void*)c))
    {
        return;
    }

    Swizzle(c, releaseSEL, releaseSELSwizzled, (IMP)SwizzledReleaseIMP);
    Swizzle(c, deallocSEL, deallocSELSwizzled, (IMP)SwizzledDeallocIMP);

    CFSetAddValue(gSwizzledClasses, (__bridge const void*)c);
}
