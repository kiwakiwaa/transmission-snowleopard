// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "CocoaCompatibility.h"

@class FileListNode;

CGFloat TRFileOutlineIconSize(FileListNode* node);
NSRect TRFileOutlineIconRect(FileListNode* node, NSRect bounds);
CGFloat TRFileOutlineTextOriginX(FileListNode* node, NSRect bounds);
NSRect TRFileOutlineTitleRect(FileListNode* node, NSAttributedString* title, NSRect bounds);
NSRect TRFileOutlineStatusRect(FileListNode* node, NSAttributedString* status, NSRect titleRect, NSRect bounds);

NSString* TRFileOutlineStatusString(FileListNode* node);
NSString* TRFileOutlinePathTooltip(FileListNode* node);
NSString* TRFileOutlineCheckTooltip(NSControlStateValue state);
NSString* TRFileOutlinePriorityTooltip(NSSet* priorities);

NSColor* TRFileOutlineTitleColor(FileListNode* node, NSBackgroundStyle backgroundStyle);
NSColor* TRFileOutlineStatusColor(FileListNode* node, NSBackgroundStyle backgroundStyle);
NSArray* TRFileOutlinePriorityImages(NSSet* priorities, NSBackgroundStyle backgroundStyle);
CGFloat TRFileOutlinePriorityImageOverlap(void);
