// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_5
#import "LegacyFoundationTypes.h"

typedef NSUInteger NSTrackingAreaOptions;

enum
{
    NSTrackingMouseEnteredAndExited = 0x01,
    NSTrackingMouseMoved = 0x02,
    NSTrackingCursorUpdate = 0x04,
    NSTrackingActiveWhenFirstResponder = 0x10,
    NSTrackingActiveInKeyWindow = 0x20,
    NSTrackingActiveInActiveApp = 0x40,
    NSTrackingActiveAlways = 0x80,
    NSTrackingAssumeInside = 0x100,
    NSTrackingInVisibleRect = 0x200,
    NSTrackingEnabledDuringMouseDrag = 0x400,
};

@interface NSTrackingArea : NSObject
{
  @private
    NSRect _rect;
    NSTrackingAreaOptions _options;
    __weak id _owner;
    NSDictionary* _userInfo;
    __unsafe_unretained NSView* _view;
    NSTrackingRectTag _trackingRectTag;
}

@property(nonatomic, readonly) NSRect rect;
@property(nonatomic, readonly) NSTrackingAreaOptions options;
@property(nonatomic, readonly) id owner;
@property(nonatomic, readonly) NSDictionary* userInfo;

- (id)initWithRect:(NSRect)rect options:(NSTrackingAreaOptions)options owner:(id)owner userInfo:(NSDictionary*)userInfo;

@end

@interface NSView (TRLegacyTrackingArea)
- (void)addTrackingArea:(NSTrackingArea*)trackingArea;
- (void)removeTrackingArea:(NSTrackingArea*)trackingArea;
- (NSArray*)trackingAreas;
- (void)updateTrackingAreas;
@end
#endif
