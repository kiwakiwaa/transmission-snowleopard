// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#import "LegacyFoundationTypes.h"

#if TR_MACOS_SDK_BEFORE_10_5 || TR_MACOS_DEPLOYMENT_BEFORE_10_5

#ifndef TR_MACOS_USE_LEGACY_VIEW_CONTROLLER
#define TR_MACOS_USE_LEGACY_VIEW_CONTROLLER 1
#endif

@interface LegacyViewController : NSResponder<NSCoding>
{
  @private
    NSString* _nibName;
    NSBundle* _nibBundle;
    id _representedObject;
    NSString* _title;
    IBOutlet NSView* view;
    NSArray* _topLevelObjects;
    NSMutableArray* _editors;
    id _autounbinder;
    NSString* _designNibBundleIdentifier;
    id _reserved[2];
}

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil;

- (void)setRepresentedObject:(id)representedObject;
- (id)representedObject;

- (void)setTitle:(NSString*)title;
- (NSString*)title;

- (NSView*)view;
- (void)loadView;

- (NSString*)nibName;
- (NSBundle*)nibBundle;

- (void)setView:(NSView*)view;

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void*)contextInfo;
- (BOOL)commitEditing;
- (void)discardEditing;

@end

#define NSViewController LegacyViewController

#endif
