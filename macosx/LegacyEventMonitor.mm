// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.

#import "LegacyEventMonitor.h"

#if TR_MACOS_SDK_BEFORE_10_6

#import <Carbon/Carbon.h>
#import <objc/objc-class.h>
#import <objc/objc-runtime.h>

#include <cstdlib>

extern "C" void* _Block_copy(void const* block);
extern "C" void _Block_release(void const* block);

@interface TRLegacyEventMonitor : NSObject
{
  @private
    NSUInteger _mask;
    void* _localHandler;
    void* _globalHandler;
    EventHandlerRef _carbonHandler;
}
@property(nonatomic, readonly) NSUInteger mask;
- (id)initLocalWithMask:(NSUInteger)mask handler:(TREventMonitorHandler __unsafe_unretained)handler;
- (id)initGlobalWithMask:(NSUInteger)mask handler:(TRGlobalEventMonitorHandler __unsafe_unretained)handler;
- (NSEvent*)handleLocalEvent:(NSEvent*)event;
- (void)handleGlobalEvent;
- (void)invalidate;
@end

@interface NSApplication (TRLegacyEventMonitorPrivate)
- (void)tr_sendEventWithoutMonitoring:(NSEvent*)event;
@end

namespace
{

IMP OriginalApplicationSendEvent;
BOOL ApplicationSendEventHookInstalled;

NSMutableArray* TRLocalEventMonitors()
{
    static NSMutableArray* monitors = nil;
    if (monitors == nil)
    {
        monitors = [[NSMutableArray alloc] init];
    }
    return monitors;
}

OSStatus TRGlobalEventMonitorCallback(EventHandlerCallRef nextHandler, EventRef carbonEvent, void* userData)
{
    (void)nextHandler;
    (void)carbonEvent;
    TRLegacyEventMonitor* monitor = (__bridge TRLegacyEventMonitor*)userData;
    if (monitor != nil)
    {
        [monitor handleGlobalEvent];
    }
    return noErr;
}

void TRApplicationSendEvent(id application, SEL selector, NSEvent* event)
{
    NSEvent* monitoredEvent = event;
    NSArray* monitors = [TRLocalEventMonitors() copy];
    NSUInteger const count = [monitors count];
    for (NSUInteger index = 0; index < count; ++index)
    {
        TRLegacyEventMonitor* monitor = [monitors objectAtIndex:index];
        if ((monitor.mask & (1UL << monitoredEvent.type)) != 0)
        {
            monitoredEvent = [monitor handleLocalEvent:monitoredEvent];
            if (monitoredEvent == nil)
            {
                return;
            }
        }
    }

    [(NSApplication*)application tr_sendEventWithoutMonitoring:monitoredEvent];
}

void TRInstallApplicationSendEventHook()
{
    if (ApplicationSendEventHookInstalled)
    {
        return;
    }

    Class applicationClass = [NSApp class];
    Method method = class_getInstanceMethod(applicationClass, sel_getUid("sendEvent:"));
    if (method == NULL)
    {
        [NSException raise:NSInternalInconsistencyException format:@"Could not install Tiger local event monitor dispatch"];
    }
    OriginalApplicationSendEvent = method->method_imp;
    struct objc_method_list* aliases = (struct objc_method_list*)std::calloc(
        1, sizeof(struct objc_method_list) + sizeof(struct objc_method));
    aliases->method_count = 1;
    aliases->method_list[0].method_name = @selector(tr_sendEventWithoutMonitoring:);
    aliases->method_list[0].method_types = method->method_types;
    aliases->method_list[0].method_imp = OriginalApplicationSendEvent;
    class_addMethods(applicationClass, aliases);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    method->method_imp = (IMP)TRApplicationSendEvent;
#pragma clang diagnostic pop
    ApplicationSendEventHookInstalled = YES;
}

}

@implementation TRLegacyEventMonitor

@synthesize mask = _mask;

- (id)initLocalWithMask:(NSUInteger)mask handler:(TREventMonitorHandler __unsafe_unretained)handler
{
    if ((self = [super init]))
    {
        _mask = mask;
        _localHandler = _Block_copy((__bridge void const*)handler);
    }
    return self;
}

- (id)initGlobalWithMask:(NSUInteger)mask handler:(TRGlobalEventMonitorHandler __unsafe_unretained)handler
{
    if ((self = [super init]))
    {
        _mask = mask;
        _globalHandler = _Block_copy((__bridge void const*)handler);

        EventTypeSpec eventType = { kEventClassMouse, kEventMouseDown };
        OSStatus const status = InstallEventHandler(
            GetEventMonitorTarget(), TRGlobalEventMonitorCallback, 1, &eventType, (__bridge void*)self, &_carbonHandler);
        if (status != noErr)
        {
            return nil;
        }
    }
    return self;
}

- (void)invalidate
{
    [TRLocalEventMonitors() removeObjectIdenticalTo:self];
    if (_carbonHandler != NULL)
    {
        RemoveEventHandler(_carbonHandler);
        _carbonHandler = NULL;
    }
    if (_localHandler != NULL)
    {
        _Block_release(_localHandler);
        _localHandler = NULL;
    }
    if (_globalHandler != NULL)
    {
        _Block_release(_globalHandler);
        _globalHandler = NULL;
    }
}

- (void)handleGlobalEvent
{
    if (_globalHandler != nil)
    {
        ((__bridge TRGlobalEventMonitorHandler)_globalHandler)(nil);
    }
}

- (NSEvent*)handleLocalEvent:(NSEvent*)event
{
    return ((__bridge TREventMonitorHandler)_localHandler)(event);
}

- (void)dealloc
{
    [self invalidate];
}

@end

@implementation NSEvent (TRLegacyEventMonitor)

+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(TREventMonitorHandler __unsafe_unretained)handler
{
    TRInstallApplicationSendEventHook();
    TRLegacyEventMonitor* monitor = [[TRLegacyEventMonitor alloc] initLocalWithMask:mask handler:handler];
    [TRLocalEventMonitors() addObject:monitor];
    return monitor;
}

+ (id)addGlobalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(TRGlobalEventMonitorHandler __unsafe_unretained)handler
{
    return [[TRLegacyEventMonitor alloc] initGlobalWithMask:mask handler:handler];
}

+ (void)removeMonitor:(id)eventMonitor
{
    [eventMonitor invalidate];
}

@end

#endif
