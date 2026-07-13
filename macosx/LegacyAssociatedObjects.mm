// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyAssociatedObjects.h"

#include <libtransmission/macos-version.h>

#if !TR_MACOS_SDK_BEFORE_10_6

#import <objc/runtime.h>

id TRLegacyGetAssociatedObject(id object, void const* key)
{
#if TR_MACOS_SDK_BEFORE_10_7
    // The 10.6 SDK declared this parameter as void*. The 10.7 SDK corrected it to void const*.
    return objc_getAssociatedObject(object, const_cast<void*>(key));
#else
    return objc_getAssociatedObject(object, key);
#endif
}

void TRLegacySetAssociatedObject(id object, void const* key, id value, TRLegacyAssociationPolicy policy)
{
    objc_AssociationPolicy objcPolicy = OBJC_ASSOCIATION_ASSIGN;
    switch (policy)
    {
    case TRLegacyAssociationRetainNonatomic:
        objcPolicy = OBJC_ASSOCIATION_RETAIN_NONATOMIC;
        break;

    case TRLegacyAssociationCopyNonatomic:
        objcPolicy = OBJC_ASSOCIATION_COPY_NONATOMIC;
        break;

    case TRLegacyAssociationAssign:
        objcPolicy = OBJC_ASSOCIATION_ASSIGN;
        break;
    }

#if TR_MACOS_SDK_BEFORE_10_7
    // The 10.6 SDK declared this parameter as void*. The 10.7 SDK corrected it to void const*.
    objc_setAssociatedObject(object, const_cast<void*>(key), value, objcPolicy);
#else
    objc_setAssociatedObject(object, key, value, objcPolicy);
#endif
}

void TRLegacyRemoveAssociatedObjects(id object)
{
    objc_removeAssociatedObjects(object);
}

#else

#import <objc/objc-class.h>
#import <objc/objc-runtime.h>

#include <cstdlib>
#include <pthread.h>

#ifndef __has_warning
#define __has_warning(x) 0
#endif

@interface TRLegacyAssignedAssociation : NSObject
{
  @private
    void* _assignedObject;
}

@property(nonatomic, readonly) id object;

- (id)initWithObject:(id)object;

@end

@implementation TRLegacyAssignedAssociation

- (id)initWithObject:(id)object
{
    if ((self = [super init]))
    {
        _assignedObject = (__bridge void*)object;
    }

    return self;
}

- (id)object
{
    return (__bridge id)_assignedObject;
}

@end

namespace
{

pthread_once_t TRLegacyAssociatedObjectStateOnce = PTHREAD_ONCE_INIT;
SEL TRLegacyDeallocSelector = NULL;
NSMutableDictionary* TRLegacyAssociatedObjects = nil;
NSMutableDictionary* TRLegacyOriginalDeallocs = nil;
pthread_key_t TRLegacyDeallocContextKey;

// A subclass can be hooked before its superclass, leaving multiple hooks in one
// dealloc chain. Each nested hook must continue below the class handled by the
// previous hook instead of looking up again from the object's dynamic class.
struct TRLegacyDeallocContext
{
    void const* object;
    Class nextClass;
    TRLegacyDeallocContext* previous;
};

struct TRLegacyOriginalDealloc
{
    IMP implementation;
    Class owner;
};

class TRLegacyDeallocContextScope
{
public:
    TRLegacyDeallocContextScope(void const* object, Class nextClass, TRLegacyDeallocContext* previous)
        : context_{ object, nextClass, previous }
    {
        pthread_setspecific(TRLegacyDeallocContextKey, &context_);
    }

    ~TRLegacyDeallocContextScope()
    {
        pthread_setspecific(TRLegacyDeallocContextKey, context_.previous);
    }

    TRLegacyDeallocContextScope(TRLegacyDeallocContextScope const&) = delete;
    TRLegacyDeallocContextScope& operator=(TRLegacyDeallocContextScope const&) = delete;

private:
    TRLegacyDeallocContext context_;
};

void TRInitializeLegacyAssociatedObjectState()
{
    TRLegacyDeallocSelector = sel_getUid("dealloc");
    TRLegacyAssociatedObjects = [[NSMutableDictionary alloc] init];
    TRLegacyOriginalDeallocs = [[NSMutableDictionary alloc] init];
    pthread_key_create(&TRLegacyDeallocContextKey, NULL);
}

void TREnsureLegacyAssociatedObjectState()
{
    pthread_once(&TRLegacyAssociatedObjectStateOnce, TRInitializeLegacyAssociatedObjectState);
}

SEL TRDeallocSelector()
{
    TREnsureLegacyAssociatedObjectState();
    return TRLegacyDeallocSelector;
}

NSMutableDictionary* TRLegacyAssociatedObjectTable()
{
    TREnsureLegacyAssociatedObjectState();
    return TRLegacyAssociatedObjects;
}

NSMutableDictionary* TRLegacyOriginalDeallocTable()
{
    TREnsureLegacyAssociatedObjectState();
    return TRLegacyOriginalDeallocs;
}

NSValue* TRPointerKey(void const* pointer)
{
    return [NSValue valueWithPointer:pointer];
}

NSMutableDictionary* TRLegacyAssociationsForObject(id object, BOOL create)
{
    NSMutableDictionary* table = TRLegacyAssociatedObjectTable();
    NSValue* objectKey = TRPointerKey((__bridge void*)object);
    NSMutableDictionary* associations = [table objectForKey:objectKey];
    if (associations == nil && create)
    {
        associations = [NSMutableDictionary dictionary];
        [table setObject:associations forKey:objectKey];
    }
    return associations;
}

Class TRClassSuperclass(Class cls)
{
    if (cls == Nil)
    {
        return Nil;
    }

    struct objc_class* runtimeClass = (__bridge struct objc_class*)cls;
    return (__bridge Class)runtimeClass->super_class;
}

Method TROwnMethod(Class cls, SEL selector)
{
    void* iterator = NULL;
    struct objc_method_list* methodList = NULL;
    while ((methodList = class_nextMethodList(cls, &iterator)) != NULL)
    {
        for (int i = 0; i < methodList->method_count; ++i)
        {
            Method method = &methodList->method_list[i];
            if (method->method_name == selector)
            {
                return method;
            }
        }
    }

    return NULL;
}

IMP TRMethodImplementation(Class cls, SEL selector)
{
    Method method = class_getInstanceMethod(cls, selector);
    return method != NULL ? method->method_imp : NULL;
}

void TRLegacyAssociatedObjectDealloc(__unsafe_unretained id self, SEL selector);

BOOL TRClassHasLegacyAssociatedObjectDeallocInHierarchy(Class cls)
{
    // An inherited hook is sufficient because a correct dealloc implementation
    // eventually calls its superclass. Keep searching past an unhooked override.
    for (Class currentClass = cls; currentClass != Nil; currentClass = TRClassSuperclass(currentClass))
    {
        Method ownDealloc = TROwnMethod(currentClass, TRDeallocSelector());
        if (ownDealloc != NULL)
        {
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#endif
            if (ownDealloc->method_imp == (IMP)TRLegacyAssociatedObjectDealloc)
            {
                return YES;
            }
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic pop
#endif
        }
    }

    return NO;
}

void TRLegacyRemoveAssociatedObjectsForPointer(void const* object)
{
    [TRLegacyAssociatedObjectTable() removeObjectForKey:TRPointerKey(object)];
}

TRLegacyOriginalDealloc TRLegacyOriginalDeallocStartingAtClass(Class cls)
{
    // Return the owner with the IMP so a nested superclass hook knows where to
    // resume. Returning only the IMP would make it select the same override again.
    NSMutableDictionary* originalDeallocs = TRLegacyOriginalDeallocTable();
    for (Class currentClass = cls; currentClass != Nil; currentClass = TRClassSuperclass(currentClass))
    {
        NSValue* stored = [originalDeallocs objectForKey:TRPointerKey((__bridge void*)currentClass)];
        if (stored != nil)
        {
            return { (IMP)[stored pointerValue], currentClass };
        }
    }

    return { NULL, Nil };
}

void TRInstallLegacyAssociatedObjectDeallocHook(id object)
{
    Class cls = [object class];
    if (cls == Nil || TRClassHasLegacyAssociatedObjectDeallocInHierarchy(cls))
    {
        return;
    }

    Method ownDealloc = TROwnMethod(cls, TRDeallocSelector());
    IMP originalImp = ownDealloc != NULL ?
        ownDealloc->method_imp : TRMethodImplementation(TRClassSuperclass(cls), TRDeallocSelector());

    [TRLegacyOriginalDeallocTable() setObject:TRPointerKey((void*)originalImp) forKey:TRPointerKey((__bridge void*)cls)];

    if (ownDealloc != NULL)
    {
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#endif
        ownDealloc->method_imp = (IMP)TRLegacyAssociatedObjectDealloc;
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic pop
#endif
        return;
    }

    // The fragile runtime has no class_addMethod(). It takes ownership of this
    // method list through class_addMethods(), so the allocation is intentionally permanent.
    struct objc_method_list* methodList = (struct objc_method_list*)std::calloc(
        1, sizeof(struct objc_method_list) + sizeof(struct objc_method));
    methodList->method_count = 1;
    methodList->method_list[0].method_name = TRDeallocSelector();
    methodList->method_list[0].method_types = (char*)"v@:";
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#endif
    methodList->method_list[0].method_imp = (IMP)TRLegacyAssociatedObjectDealloc;
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic pop
#endif
    class_addMethods(cls, methodList);
}

void TRLegacyAssociatedObjectDealloc(__unsafe_unretained id self, SEL selector)
{
    void const* const object = (__bridge void*)self;
    // The context is stack-backed and valid for the synchronous original IMP call.
    // Its scope restores the prior context for nested deallocation of other objects.
    TRLegacyDeallocContext* const previousContext =
        static_cast<TRLegacyDeallocContext*>(pthread_getspecific(TRLegacyDeallocContextKey));
    Class const startingClass = previousContext != NULL && previousContext->object == object ?
        previousContext->nextClass : [self class];
    TRLegacyOriginalDealloc originalDealloc = { NULL, Nil };
    @synchronized(TRLegacyAssociatedObjectTable())
    {
        TRLegacyRemoveAssociatedObjectsForPointer(object);
        originalDealloc = TRLegacyOriginalDeallocStartingAtClass(startingClass);
    }
    if (originalDealloc.implementation != NULL)
    {
        TRLegacyDeallocContextScope const context(object, TRClassSuperclass(originalDealloc.owner), previousContext);
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#endif
        ((void (*)(id, SEL))originalDealloc.implementation)(self, selector);
#if __has_warning("-Wcast-function-type-mismatch")
#pragma clang diagnostic pop
#endif
    }
}

}

id TRLegacyGetAssociatedObject(id object, void const* key)
{
    if (object == nil || key == NULL)
    {
        return nil;
    }

    @synchronized(TRLegacyAssociatedObjectTable())
    {
        id value = [TRLegacyAssociationsForObject(object, NO) objectForKey:TRPointerKey(key)];
        return [value isKindOfClass:NSClassFromString(@"TRLegacyAssignedAssociation")] ? [value object] : value;
    }
}

void TRLegacySetAssociatedObject(id object, void const* key, id value, TRLegacyAssociationPolicy policy)
{
    if (object == nil || key == NULL)
    {
        return;
    }

    @synchronized(TRLegacyAssociatedObjectTable())
    {
        NSMutableDictionary* associations = TRLegacyAssociationsForObject(object, value != nil);
        NSValue* associationKey = TRPointerKey(key);
        if (value == nil)
        {
            [associations removeObjectForKey:associationKey];
            if (associations.count == 0)
            {
                [TRLegacyAssociatedObjectTable() removeObjectForKey:TRPointerKey((__bridge void*)object)];
            }
            return;
        }

        TRInstallLegacyAssociatedObjectDeallocHook(object);
        id associatedValue = value;
        if (policy == TRLegacyAssociationCopyNonatomic)
        {
            associatedValue = [value copy];
        }
        else if (policy == TRLegacyAssociationAssign)
        {
            associatedValue = [[NSClassFromString(@"TRLegacyAssignedAssociation") alloc] initWithObject:value];
        }
        [associations setObject:associatedValue forKey:associationKey];
    }
}

void TRLegacyRemoveAssociatedObjects(id object)
{
    if (object == nil)
    {
        return;
    }

    @synchronized(TRLegacyAssociatedObjectTable())
    {
        TRLegacyRemoveAssociatedObjectsForPointer((__bridge void*)object);
    }
}

#endif
