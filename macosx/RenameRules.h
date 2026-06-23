// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#import "RenameRule.h"

@interface RenameRules : NSObject

+ (id<RenameRule>)replaceRuleForMode:(RenameRuleReplaceMode)mode;
+ (id<RenameRule>)appendRule;
+ (id<RenameRule>)prependRule;
+ (id<RenameRule>)dateRule;
+ (id<RenameRule>)sequenceRule;
+ (id<RenameRule>)characterRemovalRule;
+ (id<RenameRule>)regularExpressionRule;
+ (id<RenameRule>)changeCaseRule;

+ (BOOL)regularExpressionRuleAvailable;

@end
