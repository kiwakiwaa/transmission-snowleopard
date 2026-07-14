// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "PredicateEditorRowTemplateAny.h"

@implementation PredicateEditorRowTemplateAny

- (NSPredicate*)predicateWithSubpredicates:(NSArray*)subpredicates
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    NSPredicate* predicate = [super predicateWithSubpredicates:subpredicates];
    if ([predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        TRLegacyContainsPredicate* contains = (TRLegacyContainsPredicate*)predicate;
        return [[TRLegacyContainsPredicate alloc] initWithKeyPath:contains.keyPath
                                                           value:contains.value
                                                        modifier:NSAnyPredicateModifier
                                                         options:contains.options];
    }

    NSComparisonPredicate* comparison = (NSComparisonPredicate*)predicate;
    return [NSComparisonPredicate predicateWithLeftExpression:comparison.leftExpression rightExpression:comparison.rightExpression
                                                     modifier:NSAnyPredicateModifier
                                                         type:comparison.predicateOperatorType
                                                      options:comparison.options];
#else
    //we only make NSComparisonPredicates
    NSComparisonPredicate* predicate = (NSComparisonPredicate*)[super predicateWithSubpredicates:subpredicates];

    //construct a near-identical predicate
    return [NSComparisonPredicate predicateWithLeftExpression:predicate.leftExpression rightExpression:predicate.rightExpression
                                                     modifier:NSAnyPredicateModifier
                                                         type:predicate.predicateOperatorType
                                                      options:predicate.options];
#endif
}

@end
