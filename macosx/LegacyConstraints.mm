// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyConstraints.h"

#include <libtransmission/macos-version.h>

static BOOL TRSendConstraintArraySelector(SEL selector, NSArray* constraints)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
    (void)selector;
    (void)constraints;
    return NO;
#else
    if (![NSLayoutConstraint respondsToSelector:selector])
    {
        return NO;
    }

    typedef void (*ConstraintArraySelector)(id, SEL, NSArray*);
    ConstraintArraySelector const method = (ConstraintArraySelector)[NSLayoutConstraint methodForSelector:selector];
    method(NSLayoutConstraint.class, selector, constraints);
    return YES;
#endif
}

static BOOL TRSendConstraintActiveSetter(NSLayoutConstraint* constraint, BOOL active)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_7
    (void)constraint;
    (void)active;
    return NO;
#else
    SEL const selector = @selector(setActive:);
    if (![constraint respondsToSelector:selector])
    {
        return NO;
    }

    typedef void (*ConstraintActiveSetter)(id, SEL, BOOL);
    ConstraintActiveSetter const method = (ConstraintActiveSetter)[constraint methodForSelector:selector];
    method(constraint, selector, active);
    return YES;
#endif
}

NSLayoutConstraint* TRMakeLayoutConstraint(
    id view1,
    NSLayoutAttribute attr1,
    NSLayoutRelation relation,
    id view2,
    NSLayoutAttribute attr2,
    CGFloat constant)
{
    return [NSLayoutConstraint constraintWithItem:view1
                                        attribute:attr1
                                        relatedBy:relation
                                           toItem:view2
                                        attribute:attr2
                                       multiplier:1.0
                                         constant:constant];
}

void TRActivateConstraints(NSView* owner, NSArray* constraints)
{
    if (constraints.count == 0)
    {
        return;
    }

    if (!TRSendConstraintArraySelector(@selector(activateConstraints:), constraints))
    {
        [owner addConstraints:constraints];
    }
}

void TRDeactivateConstraints(NSView* owner, NSArray* constraints)
{
    if (constraints.count == 0)
    {
        return;
    }

    if (!TRSendConstraintArraySelector(@selector(deactivateConstraints:), constraints))
    {
        [owner removeConstraints:constraints];
    }
}

void TRSetConstraintActive(NSLayoutConstraint* constraint, BOOL active)
{
    if (TRSendConstraintActiveSetter(constraint, active))
    {
        return;
    }

    id firstItem = [constraint firstItem];
    if (![firstItem respondsToSelector:@selector(addConstraint:)])
    {
        return;
    }

    if (active)
    {
        [firstItem addConstraint:constraint];
    }
    else
    {
        [firstItem removeConstraint:constraint];
    }
}
