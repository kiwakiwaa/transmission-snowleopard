// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

FOUNDATION_EXPORT BOOL TRCheckExpectedStackViewClass(id stackView, NSString* ownerName, NSString* outletName);

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090

typedef NS_ENUM(NSInteger, TRLegacyStackViewOrientation) {
    TRLegacyStackViewOrientationHorizontal = 0,
    TRLegacyStackViewOrientationVertical = 1,
};

typedef NS_ENUM(NSInteger, TRLegacyStackViewAlignment) {
    TRLegacyStackViewAlignmentNotAnAttribute = 0,
    TRLegacyStackViewAlignmentLeft = 1,
    TRLegacyStackViewAlignmentRight = 2,
    TRLegacyStackViewAlignmentTop = 3,
    TRLegacyStackViewAlignmentBottom = 4,
    TRLegacyStackViewAlignmentLeading = 5,
    TRLegacyStackViewAlignmentTrailing = 6,
    TRLegacyStackViewAlignmentWidth = 7,
    TRLegacyStackViewAlignmentHeight = 8,
    TRLegacyStackViewAlignmentCenterX = 9,
    TRLegacyStackViewAlignmentCenterY = 10,
    TRLegacyStackViewAlignmentLastBaseline = 11,
};

typedef NS_ENUM(NSInteger, TRLegacyStackViewGravity) {
    TRLegacyStackViewGravityTop = 1,
    TRLegacyStackViewGravityLeading = 1,
    TRLegacyStackViewGravityCenter = 2,
    TRLegacyStackViewGravityBottom = 3,
    TRLegacyStackViewGravityTrailing = 3,
};

typedef CGFloat TRLegacyStackViewVisibilityPriority;
static TRLegacyStackViewVisibilityPriority const TRLegacyStackViewVisibilityPriorityNotVisible = 0.0;
static TRLegacyStackViewVisibilityPriority const TRLegacyStackViewVisibilityPriorityMustHold = 1000.0;

@interface LegacyStackView : NSView

@property(nonatomic, readonly, copy) NSArray* arrangedSubviews;
@property(nonatomic, readonly, copy) NSArray* views;
@property(nonatomic, readonly, copy) NSArray* detachedViews;
@property(nonatomic) TRLegacyStackViewOrientation orientation;
@property(nonatomic) TRLegacyStackViewAlignment alignment;
@property(nonatomic) CGFloat spacing;
@property(nonatomic) BOOL detachesHiddenViews;

+ (instancetype)stackViewWithViews:(NSArray*)views;

- (void)addArrangedSubview:(NSView*)view;
- (void)insertArrangedSubview:(NSView*)view atIndex:(NSUInteger)index;
- (void)removeArrangedSubview:(NSView*)view;

- (void)addView:(NSView*)view inGravity:(TRLegacyStackViewGravity)gravity;
- (void)insertView:(NSView*)view atIndex:(NSUInteger)index inGravity:(TRLegacyStackViewGravity)gravity;
- (void)removeView:(NSView*)view;
- (NSArray*)viewsInGravity:(TRLegacyStackViewGravity)gravity;
- (void)setViews:(NSArray*)views inGravity:(TRLegacyStackViewGravity)gravity;

- (void)invalidateLegacyLayout;
- (void)layoutLegacySubviews;

- (void)setVisibilityPriority:(TRLegacyStackViewVisibilityPriority)priority forView:(NSView*)view;
- (TRLegacyStackViewVisibilityPriority)visibilityPriorityForView:(NSView*)view;

- (CGFloat)huggingPriorityForOrientation:(TRLegacyStackViewOrientation)orientation;
- (void)setHuggingPriority:(CGFloat)priority forOrientation:(TRLegacyStackViewOrientation)orientation;
- (CGFloat)clippingResistancePriorityForOrientation:(TRLegacyStackViewOrientation)orientation;
- (void)setClippingResistancePriority:(CGFloat)priority forOrientation:(TRLegacyStackViewOrientation)orientation;

@end

#endif
