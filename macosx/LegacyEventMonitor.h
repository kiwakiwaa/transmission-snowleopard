// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.

#pragma once

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_6
#import "LegacyFoundationTypes.h"

typedef NSEvent* (^TREventMonitorHandler)(NSEvent* event);
typedef void (^TRGlobalEventMonitorHandler)(NSEvent* event);

@interface NSEvent (TRLegacyEventMonitor)
+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(TREventMonitorHandler __unsafe_unretained)handler;
+ (id)addGlobalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(TRGlobalEventMonitorHandler __unsafe_unretained)handler;
+ (void)removeMonitor:(id)eventMonitor;
@end
#endif
