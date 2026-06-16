// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

NSLayoutConstraint* TRMakeLayoutConstraint(
    id view1,
    NSLayoutAttribute attr1,
    NSLayoutRelation relation,
    id view2,
    NSLayoutAttribute attr2,
    CGFloat constant);
void TRActivateConstraints(NSView* owner, NSArray* constraints);
void TRDeactivateConstraints(NSView* owner, NSArray* constraints);
void TRSetConstraintActive(NSLayoutConstraint* constraint, BOOL active);
