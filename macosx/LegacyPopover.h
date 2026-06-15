// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_7

@class TRLegacyPopover;

@protocol TRLegacyPopoverDelegate
@optional
- (BOOL)popoverShouldClose:(TRLegacyPopover*)popover;
- (void)popoverWillShow:(NSNotification*)notification;
- (void)popoverDidShow:(NSNotification*)notification;
- (void)popoverWillClose:(NSNotification*)notification;
- (void)popoverDidClose:(NSNotification*)notification;
@end

typedef NSInteger NSPopoverBehavior;
static NSPopoverBehavior const NSPopoverBehaviorApplicationDefined = 0;
static NSPopoverBehavior const NSPopoverBehaviorTransient = 1;
static NSPopoverBehavior const NSPopoverBehaviorSemitransient = 2;

@interface TRLegacyPopover : NSResponder

@property(nonatomic) NSPopoverBehavior behavior;
@property(nonatomic, retain) NSViewController* contentViewController;
@property(nonatomic, assign) id<TRLegacyPopoverDelegate> delegate;
@property(nonatomic, readonly, getter=isShown) BOOL shown;

- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView*)positioningView preferredEdge:(NSRectEdge)preferredEdge;
- (void)close;
- (void)performClose:(id)sender;

@end

#define NSPopover TRLegacyPopover
#define NSPopoverDelegate TRLegacyPopoverDelegate

#endif
