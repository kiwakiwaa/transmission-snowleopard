// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "CocoaCompatibility.h"

NSString* TRFileOutlineCheckTooltip(NSControlStateValue state);
NSString* TRFileOutlinePriorityTooltip(NSSet* priorities);

NSArray* TRFileOutlinePriorityImages(NSSet* priorities, NSBackgroundStyle backgroundStyle);
CGFloat TRFileOutlinePriorityImageOverlap(void);
