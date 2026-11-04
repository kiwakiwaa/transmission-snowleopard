// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "GroupsController.h"
#import "CocoaCompatibility.h"
#import "LegacyArchiving.h"
#import "LegacyPredicateEditor.h"
#import "NSImageAdditions.h"
#import "NSMutableArrayAdditions.h"

#include <libtransmission/transmission.h>

static CGFloat const kIconWidth = 16.0;
static CGFloat const kBorderWidth = 1.25;
static CGFloat const kIconWidthSmall = 12.0;
static NSString* const kAnnouncedClientIdentityKey = @"AnnouncedClientIdentity";
static NSString* const kAnnounceClientVersionKey = @"AnnounceClientVersion";
static NSString* const kRealAnnouncedClientIdentity = @"real";

static NSString* TRStringFromUTF8(char const* value)
{
    return value != nullptr ? [NSString stringWithUTF8String:value] : nil;
}

static NSString* TRSupportedAnnouncedClientIdentity(NSString* value)
{
    if (value.length == 0)
    {
        return nil;
    }

    for (size_t i = 0, n = tr_announcedClientIdentityCount(); i < n; ++i)
    {
        tr_announced_client_identity_info const identity = tr_announcedClientIdentity(i);
        if ([value isEqualToString:TRStringFromUTF8(identity.id)])
        {
            return [value isEqualToString:kRealAnnouncedClientIdentity] ? nil : value;
        }
    }

    NSString* migratedIdentity = [@"transmission-" stringByAppendingString:value];
    for (size_t i = 0, n = tr_announcedClientIdentityCount(); i < n; ++i)
    {
        tr_announced_client_identity_info const identity = tr_announcedClientIdentity(i);
        if ([migratedIdentity isEqualToString:TRStringFromUTF8(identity.id)])
        {
            return migratedIdentity;
        }
    }

    return nil;
}

// Store rules as bounded data trees. Archived predicate objects must never be
// evaluated, even on Foundation versions without secure unarchiving support.
static NSUInteger const kAutoGroupRuleMaxDepth = 8;
static NSUInteger const kAutoGroupRuleMaxChildren = 32;
static NSUInteger const kAutoGroupRuleMaxTotalNodes = 256;

static NSSet* allowedAutoGroupRuleKeyPaths(void)
{
    static NSSet* keyPaths;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Keep this list aligned with the rule editor templates.
        keyPaths = [NSSet setWithObjects:@"name", @"comment", @"flatFileList.name", @"allTrackersFlat", nil];
    });
    return keyPaths;
}

static BOOL autoGroupRuleOperatorIsAllowed(NSPredicateOperatorType type)
{
    switch (type)
    {
    case NSEqualToPredicateOperatorType:
    case NSNotEqualToPredicateOperatorType:
    case NSBeginsWithPredicateOperatorType:
    case NSEndsWithPredicateOperatorType:
    case (NSPredicateOperatorType)99:
    case NSMatchesPredicateOperatorType:
        return YES;
    case NSLessThanPredicateOperatorType:
    case NSLessThanOrEqualToPredicateOperatorType:
    case NSGreaterThanPredicateOperatorType:
    case NSGreaterThanOrEqualToPredicateOperatorType:
    case NSLikePredicateOperatorType:
    case NSInPredicateOperatorType:
    case NSCustomSelectorPredicateOperatorType:
#if !TR_MACOS_SDK_BEFORE_10_5
    case NSBetweenPredicateOperatorType:
#endif
        return NO;
    }
    return NO;
}

static BOOL autoGroupRuleModifierIsAllowed(NSComparisonPredicateModifier modifier)
{
    return modifier == NSDirectPredicateModifier || modifier == NSAllPredicateModifier || modifier == NSAnyPredicateModifier;
}

static BOOL autoGroupRuleOptionsAreAllowed(NSUInteger options)
{
    return (options & ~(NSCaseInsensitivePredicateOption | NSDiacriticInsensitivePredicateOption)) == 0;
}

static BOOL autoGroupRuleCompoundTypeIsAllowed(NSCompoundPredicateType type)
{
    return type == NSNotPredicateType || type == NSAndPredicateType || type == NSOrPredicateType;
}

static NSDictionary* safeSchemaFromArchivedAutoGroupRule(NSDictionary*, NSUInteger, NSUInteger*);
static NSPredicate* autoGroupPredicateFromSafeSchema(NSDictionary*, NSUInteger, NSUInteger*);

static NSDictionary* safeSchemaFromAutoGroupPredicate(NSPredicate* predicate, NSUInteger depth, NSUInteger* remainingNodeBudget)
{
    if (depth > kAutoGroupRuleMaxDepth || *remainingNodeBudget == 0)
    {
        return nil;
    }
    (*remainingNodeBudget)--;

    if ([predicate isKindOfClass:NSCompoundPredicate.class])
    {
        NSCompoundPredicate* compound = (NSCompoundPredicate*)predicate;
        if (!autoGroupRuleCompoundTypeIsAllowed(compound.compoundPredicateType) || compound.subpredicates.count > kAutoGroupRuleMaxChildren)
        {
            return nil;
        }

        NSMutableArray* subSchemas = [NSMutableArray arrayWithCapacity:compound.subpredicates.count];
        for (NSPredicate* subPredicate in compound.subpredicates)
        {
            NSDictionary* subSchema = safeSchemaFromAutoGroupPredicate(subPredicate, depth + 1, remainingNodeBudget);
            if (!subSchema)
            {
                return nil;
            }
            [subSchemas addObject:subSchema];
        }

        // Mutable containers keep the schema readable by older builds.
        return
            [@{@"Type" : @"Compound",
               @"Compound" : @(compound.compoundPredicateType),
               @"Subpredicates" : subSchemas} mutableCopy];
    }

    predicate = TRNativePredicateFromLegacyContainsPredicate(predicate);
    if ([predicate isKindOfClass:TRLegacyContainsPredicate.class])
    {
        TRLegacyContainsPredicate* contains = (TRLegacyContainsPredicate*)predicate;
        NSDictionary* record = @{
            @"TRArchivedClass" : @"TRLegacyContainsPredicate",
            @"keyPath" : contains.keyPath,
            @"value" : contains.value,
            @"modifier" : @(contains.modifier),
            @"options" : @(contains.options)
        };
        NSDictionary* schema = safeSchemaFromArchivedAutoGroupRule(record, depth, remainingNodeBudget);
        return autoGroupPredicateFromSafeSchema(schema, 0, remainingNodeBudget) ? schema : nil;
    }
    if ([predicate isKindOfClass:NSComparisonPredicate.class])
    {
        NSComparisonPredicate* comparison = (NSComparisonPredicate*)predicate;
        if (!autoGroupRuleOperatorIsAllowed(comparison.predicateOperatorType) ||
            !autoGroupRuleModifierIsAllowed(comparison.comparisonPredicateModifier) ||
            !autoGroupRuleOptionsAreAllowed(comparison.options))
        {
            return nil;
        }

        NSExpression* left = comparison.leftExpression;
        NSExpression* right = comparison.rightExpression;
        if (left.expressionType != NSKeyPathExpressionType || !left.keyPath || ![allowedAutoGroupRuleKeyPaths() containsObject:left.keyPath])
        {
            return nil;
        }
        if (right.expressionType != NSConstantValueExpressionType ||
            (right.constantValue && ![right.constantValue isKindOfClass:NSString.class] &&
             ![right.constantValue isKindOfClass:NSNumber.class]))
        {
            return nil;
        }

        NSMutableDictionary* schema = [@{
            @"Type" : @"Comparison",
            @"KeyPath" : left.keyPath,
            @"Modifier" : @(comparison.comparisonPredicateModifier),
            @"Operator" : @(comparison.predicateOperatorType),
            @"Options" : @(comparison.options)
        } mutableCopy];
        if (right.constantValue)
        {
            schema[@"Value"] = right.constantValue;
        }
        return schema;
    }

    return nil;
}

static NSPredicate* autoGroupPredicateFromSafeSchema(NSDictionary* schema, NSUInteger depth, NSUInteger* remainingNodeBudget)
{
    if (depth > kAutoGroupRuleMaxDepth || *remainingNodeBudget == 0 || ![schema isKindOfClass:NSDictionary.class])
    {
        return nil;
    }
    (*remainingNodeBudget)--;

    NSString* type = schema[@"Type"];
    if (![type isKindOfClass:NSString.class])
    {
        return nil;
    }
    if ([type isEqualToString:@"Compound"])
    {
        NSNumber* compoundTypeNumber = schema[@"Compound"];
        NSArray* subSchemas = schema[@"Subpredicates"];
        if (![compoundTypeNumber isKindOfClass:NSNumber.class] || ![subSchemas isKindOfClass:NSArray.class] || subSchemas.count > kAutoGroupRuleMaxChildren)
        {
            return nil;
        }

        NSCompoundPredicateType compoundType = (NSCompoundPredicateType)compoundTypeNumber.integerValue;
        if (!autoGroupRuleCompoundTypeIsAllowed(compoundType))
        {
            return nil;
        }

        NSMutableArray* subPredicates = [NSMutableArray arrayWithCapacity:subSchemas.count];
        for (NSDictionary* subSchema in subSchemas)
        {
            NSPredicate* subPredicate = autoGroupPredicateFromSafeSchema(subSchema, depth + 1, remainingNodeBudget);
            if (!subPredicate)
            {
                return nil;
            }
            [subPredicates addObject:subPredicate];
        }

        if (compoundType == NSNotPredicateType)
        {
            return subPredicates.count == 1 ? [NSCompoundPredicate notPredicateWithSubpredicate:[subPredicates objectAtIndex:0]] : nil;
        }
        return [[NSCompoundPredicate alloc] initWithType:compoundType subpredicates:subPredicates];
    }

    if ([type isEqualToString:@"Comparison"])
    {
        NSString* keyPath = schema[@"KeyPath"];
        NSNumber* modifierNumber = schema[@"Modifier"];
        NSNumber* operatorNumber = schema[@"Operator"];
        NSNumber* optionsNumber = schema[@"Options"];
        id value = schema[@"Value"];

        if (![keyPath isKindOfClass:NSString.class] || ![allowedAutoGroupRuleKeyPaths() containsObject:keyPath] ||
            ![modifierNumber isKindOfClass:NSNumber.class] || ![operatorNumber isKindOfClass:NSNumber.class] ||
            ![optionsNumber isKindOfClass:NSNumber.class] ||
            (value && ![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]))
        {
            return nil;
        }

        NSComparisonPredicateModifier modifier = (NSComparisonPredicateModifier)modifierNumber.integerValue;
        NSPredicateOperatorType operatorType = (NSPredicateOperatorType)operatorNumber.integerValue;
        NSUInteger options = optionsNumber.unsignedIntegerValue;
        if (!autoGroupRuleModifierIsAllowed(modifier) || !autoGroupRuleOperatorIsAllowed(operatorType) ||
            !autoGroupRuleOptionsAreAllowed(options))
        {
            return nil;
        }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
        if ((NSUInteger)operatorType == 99)
        {
            return [[TRLegacyContainsPredicate alloc] initWithKeyPath:keyPath value:value modifier:modifier options:options];
        }
#endif
        NSExpression* left = [NSExpression expressionForKeyPath:keyPath];
        NSExpression* right = [NSExpression expressionForConstantValue:value];
        return [NSComparisonPredicate predicateWithLeftExpression:left rightExpression:right modifier:modifier type:operatorType
                                                          options:options];
    }

    return nil;
}

static NSDictionary* safeSchemaFromArchivedAutoGroupRule(NSDictionary* record, NSUInteger depth, NSUInteger* budget)
{
    if (depth > kAutoGroupRuleMaxDepth || *budget == 0 || ![record isKindOfClass:NSDictionary.class])
    {
        return nil;
    }
    --*budget;
    NSString* className = record[@"TRArchivedClass"];
    if (![className isKindOfClass:NSString.class])
    {
        return nil;
    }
    if ([className isEqualToString:@"NSCompoundPredicate"])
    {
        NSNumber* type = record[@"NSCompoundPredicateType"];
        NSArray* children = record[@"NSSubpredicates"];
        if (![type isKindOfClass:NSNumber.class] || ![children isKindOfClass:NSArray.class] || children.count > kAutoGroupRuleMaxChildren)
        {
            return nil;
        }
        NSMutableArray* schemas = [NSMutableArray array];
        for (NSDictionary* child in children)
        {
            NSDictionary* schema = safeSchemaFromArchivedAutoGroupRule(child, depth + 1, budget);
            if (!schema)
            {
                return nil;
            }
            [schemas addObject:schema];
        }
        return @{ @"Type" : @"Compound", @"Compound" : type, @"Subpredicates" : schemas };
    }
    if ([className isEqualToString:@"TRLegacyContainsPredicate"])
    {
        id key = record[@"keyPath"];
        id value = record[@"value"];
        id modifier = record[@"modifier"];
        id options = record[@"options"];
        if (![key isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class] ||
            ![modifier isKindOfClass:NSNumber.class] || ![options isKindOfClass:NSNumber.class])
        {
            return nil;
        }
        return @{
            @"Type" : @"Comparison",
            @"KeyPath" : key,
            @"Value" : value,
            @"Modifier" : modifier,
            @"Operator" : @99,
            @"Options" : options
        };
    }
    if (![className isEqualToString:@"NSComparisonPredicate"])
    {
        return nil;
    }
    NSDictionary* left = record[@"NSLeftExpression"];
    NSDictionary* right = record[@"NSRightExpression"];
    NSDictionary* operation = record[@"NSPredicateOperator"];
    if (![left isKindOfClass:NSDictionary.class] || ![right isKindOfClass:NSDictionary.class] ||
        ![operation isKindOfClass:NSDictionary.class] || ![left[@"TRArchivedClass"] isEqual:@"NSKeyPathExpression"] ||
        ![right[@"TRArchivedClass"] isEqual:@"NSConstantValueExpression"])
    {
        return nil;
    }
    NSArray* arguments = left[@"NSArguments"];
    if (![arguments isKindOfClass:NSArray.class] || arguments.count != 1 || ![arguments[0] isKindOfClass:NSDictionary.class])
    {
        return nil;
    }
    NSDictionary* keyExpression = arguments[0];
    id key = keyExpression[@"NSKeyPath"];
    id value = right[@"NSConstantValue"];
    id modifier = operation[@"NSModifier"];
    id type = operation[@"NSOperatorType"];
    id options = operation[@"NSFlags"] ?: operation[@"NSOptions"];
    if (![keyExpression[@"TRArchivedClass"] isEqual:@"NSKeyPathSpecifierExpression"] || ![key isKindOfClass:NSString.class] ||
        (value && ![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]) ||
        ![modifier isKindOfClass:NSNumber.class] || ![type isKindOfClass:NSNumber.class] || ![options isKindOfClass:NSNumber.class])
    {
        return nil;
    }
    NSMutableDictionary* schema = [@{
        @"Type" : @"Comparison",
        @"KeyPath" : key,
        @"Modifier" : modifier,
        @"Operator" : type,
        @"Options" : options
    } mutableCopy];
    if (value)
    {
        schema[@"Value"] = value;
    }
    return schema;
}

@interface GroupsController ()

@property(nonatomic, readonly) NSMutableArray* fGroups;

- (NSMutableArray*)decodedGroupsFromArchivedData:(NSData*)data
                                                    migratedLegacyRule:(BOOL*)migratedLegacyRule;
- (void)saveGroups;

@end

@implementation GroupsController

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize fGroups = _fGroups;
#endif

+ (GroupsController*)groups
{
    static GroupsController* fGroupsInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fGroupsInstance = [[GroupsController alloc] init];
    });

    return fGroupsInstance;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        NSData* data;
        if ((data = [NSUserDefaults.standardUserDefaults dataForKey:@"GroupDicts"]))
        {
            BOOL migratedLegacyRule = NO;
            _fGroups = [self decodedGroupsFromArchivedData:data migratedLegacyRule:&migratedLegacyRule];
            if (_fGroups != nil && migratedLegacyRule)
            {
                // Rewrite supported old rules as data before the next save.
                [self saveGroups];
            }
        }
        else if ([NSUserDefaults.standardUserDefaults objectForKey:@"Groups"])
        {
            // This obsolete format requires unrestricted object decoding.
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"Groups"];
        }
        if (_fGroups == nil)
        {
            //default groups
            NSMutableDictionary* red = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemRedColor(), @"Color", NSLocalizedString(@"Red", "Groups -> Name"), @"Name", @0, @"Index", nil];

            NSMutableDictionary* orange = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemOrangeColor(), @"Color", NSLocalizedString(@"Orange", "Groups -> Name"), @"Name", @1, @"Index", nil];

            NSMutableDictionary* yellow = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemYellowColor(), @"Color", NSLocalizedString(@"Yellow", "Groups -> Name"), @"Name", @2, @"Index", nil];

            NSMutableDictionary* green = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemGreenColor(), @"Color", NSLocalizedString(@"Green", "Groups -> Name"), @"Name", @3, @"Index", nil];

            NSMutableDictionary* blue = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemBlueColor(), @"Color", NSLocalizedString(@"Blue", "Groups -> Name"), @"Name", @4, @"Index", nil];

            NSMutableDictionary* purple = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemPurpleColor(), @"Color", NSLocalizedString(@"Purple", "Groups -> Name"), @"Name", @5, @"Index", nil];

            NSMutableDictionary* gray = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:TRSystemGrayColor(), @"Color", NSLocalizedString(@"Gray", "Groups -> Name"), @"Name", @6, @"Index", nil];

            _fGroups = [[NSMutableArray alloc] initWithObjects:red, orange, yellow, green, blue, purple, gray, nil];
            [self saveGroups]; //make sure this is saved right away
        }
    }

    return self;
}

- (NSInteger)numberOfGroups
{
    return self.fGroups.count;
}

- (NSInteger)rowValueForIndex:(NSInteger)index
{
    if (index != -1)
    {
        for (NSUInteger i = 0; i < self.fGroups.count; i++)
        {
            if (index == [self.fGroups[i][@"Index"] integerValue])
            {
                return i;
            }
        }
    }
    return -1;
}

- (NSInteger)indexForRow:(NSInteger)row
{
    return [self.fGroups[row][@"Index"] integerValue];
}

- (NSString*)nameForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? self.fGroups[orderIndex][@"Name"] : nil;
}

- (void)setName:(NSString*)name forIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    self.fGroups[orderIndex][@"Name"] = name;
    [self saveGroups];

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (NSImage*)imageForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? [self imageForGroup:self.fGroups[orderIndex]] : [self imageForGroupNone];
}

- (NSColor*)colorForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? self.fGroups[orderIndex][@"Color"] : nil;
}

- (void)setColor:(NSColor*)color forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];
    [dict removeObjectForKey:@"Icon"];

    dict[@"Color"] = color;

    [GroupsController.groups saveGroups];
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (BOOL)usesCustomDownloadLocationForIndex:(NSInteger)index
{
    if (![self customDownloadLocationForIndex:index])
    {
        return NO;
    }

    NSInteger orderIndex = [self rowValueForIndex:index];
    return [self.fGroups[orderIndex][@"UsesCustomDownloadLocation"] boolValue];
}

- (void)setUsesCustomDownloadLocation:(BOOL)useCustomLocation forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];

    dict[@"UsesCustomDownloadLocation"] = @(useCustomLocation);

    [GroupsController.groups saveGroups];
}

- (NSString*)customDownloadLocationForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? self.fGroups[orderIndex][@"CustomDownloadLocation"] : nil;
}

- (void)setCustomDownloadLocation:(NSString*)location forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];
    dict[@"CustomDownloadLocation"] = location;

    [GroupsController.groups saveGroups];
}

- (BOOL)usesAutoAssignRulesForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    if (orderIndex == -1)
    {
        return NO;
    }

    NSNumber* assignRules = self.fGroups[orderIndex][@"UsesAutoGroupRules"];
    return assignRules && assignRules.boolValue;
}

- (void)setUsesAutoAssignRules:(BOOL)useAutoAssignRules forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];

    dict[@"UsesAutoGroupRules"] = @(useAutoAssignRules);

    [GroupsController.groups saveGroups];
}

- (NSPredicate*)autoAssignRulesForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    if (orderIndex == -1)
    {
        return nil;
    }

    return self.fGroups[orderIndex][@"AutoGroupRules"];
}

- (void)setAutoAssignRules:(NSPredicate*)predicate forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];

    if (predicate)
    {
        // Catch rule-editor shapes that cannot be saved safely.
        NSUInteger assertNodeBudget = kAutoGroupRuleMaxTotalNodes;
        // NSAssert compiles out in Release builds.
        (void)assertNodeBudget;
        NSAssert(
            safeSchemaFromAutoGroupPredicate(predicate, 0, &assertNodeBudget) != nil,
            @"Auto-assign rule predicate (%@) doesn't match the allowlisted schema and would be silently discarded on save",
            predicate);

        dict[@"AutoGroupRules"] = predicate;
        [GroupsController.groups saveGroups];
    }
    else
    {
        [dict removeObjectForKey:@"AutoGroupRules"];
        [self setUsesAutoAssignRules:NO forIndex:index];
    }
}

- (NSString*)announcedClientIdentityForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    if (orderIndex == -1)
    {
        return nil;
    }

    NSDictionary* dict = self.fGroups[orderIndex];
    NSString* identity = TRSupportedAnnouncedClientIdentity(dict[kAnnouncedClientIdentityKey]);
    return identity != nil ? identity : TRSupportedAnnouncedClientIdentity(dict[kAnnounceClientVersionKey]);
}

- (void)setAnnouncedClientIdentity:(NSString*)identity forIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    if (orderIndex == -1)
    {
        return;
    }

    NSString* supportedIdentity = TRSupportedAnnouncedClientIdentity(identity);
    if (identity.length > 0 && supportedIdentity == nil)
    {
        return;
    }

    NSMutableDictionary* dict = self.fGroups[orderIndex];
    if (supportedIdentity.length > 0)
    {
        dict[kAnnouncedClientIdentityKey] = supportedIdentity;
    }
    else
    {
        [dict removeObjectForKey:kAnnouncedClientIdentityKey];
    }
    [dict removeObjectForKey:kAnnounceClientVersionKey];

    [GroupsController.groups saveGroups];
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (void)addNewGroup
{
    //find the lowest index
    NSMutableIndexSet* candidates = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.fGroups.count + 1)];
    for (NSDictionary* dict in self.fGroups)
    {
        [candidates removeIndex:[dict[@"Index"] integerValue]];
    }

    NSInteger const index = candidates.firstIndex;

    [self.fGroups addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@(index),
                                                                              @"Index",
                                                                              [NSColor colorWithCalibratedRed:0.0 green:0.65
                                                                                                         blue:1.0
                                                                                                        alpha:1.0],
                                                                              @"Color",
                                                                              @"",
                                                                              @"Name",
                                                                              nil]];

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
    [self saveGroups];
}

- (void)removeGroupWithRowIndex:(NSInteger)row
{
    NSInteger index = [self.fGroups[row][@"Index"] integerValue];
    [self.fGroups removeObjectAtIndex:row];

    [NSNotificationCenter.defaultCenter postNotificationName:@"GroupValueRemoved" object:self
                                                    userInfo:@{ @"Index" : @(index) }];

    if (index == [NSUserDefaults.standardUserDefaults integerForKey:@"FilterGroup"])
    {
        [NSUserDefaults.standardUserDefaults setInteger:-2 forKey:@"FilterGroup"];
    }

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
    [self saveGroups];
}

- (void)moveGroupAtRow:(NSInteger)oldRow toRow:(NSInteger)newRow
{
    [self.fGroups moveObjectAtIndex:oldRow toIndex:newRow];

    [self saveGroups];
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (NSMenu*)groupMenuWithTarget:(id)target action:(SEL)action isSmall:(BOOL)small
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];

    void (^addItemWithTitleTagIcon)(NSString*, NSInteger, NSImage*) = ^void(NSString* title, NSInteger tag, NSImage* icon) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
        item.target = target;
        item.tag = tag;

        if (small)
        {
            icon = [icon copy];
            icon.size = NSMakeSize(kIconWidthSmall, kIconWidthSmall);

            item.image = icon;
        }
        else
        {
            item.image = icon;
        }

        [menu addItem:item];
    };

    addItemWithTitleTagIcon(NSLocalizedString(@"None", "Groups -> Menu"), -1, [self imageForGroupNone]);

    for (NSMutableDictionary* dict in self.fGroups)
    {
        addItemWithTitleTagIcon(dict[@"Name"], [dict[@"Index"] integerValue], [self imageForGroup:dict]);
    }

    return menu;
}

- (NSInteger)groupIndexForTorrent:(Torrent*)torrent
{
    for (NSDictionary* group in self.fGroups)
    {
        NSInteger row = [group[@"Index"] integerValue];
        if ([self torrent:torrent doesMatchRulesForGroupAtIndex:row])
        {
            return row;
        }
    }
    return -1;
}

#pragma mark - Private

- (NSMutableArray*)decodedGroupsFromArchivedData:(NSData*)data
                                                    migratedLegacyRule:(BOOL*)migratedLegacyRule
{
    id decoded;
    @try
    {
        decoded = TRReadGroupArchive(data);
    }
    @catch (NSException* exception)
    {
        NSLog(@"Error when decoding groups (%@)", exception);
        return nil;
    }

    if (![decoded isKindOfClass:NSArray.class])
    {
        return nil;
    }

    NSMutableArray* validatedGroups = [NSMutableArray arrayWithCapacity:[(NSArray*)decoded count]];
    for (id groupObject in (NSArray*)decoded)
    {
        if (![groupObject isKindOfClass:NSDictionary.class] || ![((NSDictionary*)groupObject)[@"Index"] isKindOfClass:NSNumber.class])
        {
            // One malformed entry must not prevent other groups from loading.
            continue;
        }

        NSMutableDictionary* group = [groupObject mutableCopy];
        if (![group[@"Name"] isKindOfClass:NSString.class])
        {
            group[@"Name"] = @"";
        }
        if (![group[@"Color"] isKindOfClass:NSColor.class])
        {
            group[@"Color"] = [NSColor grayColor];
        }
        for (NSString* key in @[ kAnnouncedClientIdentityKey, kAnnounceClientVersionKey ])
        {
            if (group[key] && ![group[key] isKindOfClass:NSString.class])
            {
                [group removeObjectForKey:key];
            }
        }

        NSDictionary* schema = group[@"AutoGroupRulesSchema"];
        id legacyPredicate = group[@"AutoGroupRules"];
        [group removeObjectForKey:@"AutoGroupRulesSchema"];

        NSPredicate* rebuilt = nil;
        if ([schema isKindOfClass:NSDictionary.class])
        {
            NSUInteger nodeBudget = kAutoGroupRuleMaxTotalNodes;
            rebuilt = autoGroupPredicateFromSafeSchema(schema, 0, &nodeBudget);
        }
        else if ([legacyPredicate isKindOfClass:NSDictionary.class])
        {
            NSUInteger schemaNodeBudget = kAutoGroupRuleMaxTotalNodes;
            NSDictionary* legacySchema = safeSchemaFromArchivedAutoGroupRule(legacyPredicate, 0, &schemaNodeBudget);
            NSUInteger rebuildNodeBudget = kAutoGroupRuleMaxTotalNodes;
            rebuilt = legacySchema ? autoGroupPredicateFromSafeSchema(legacySchema, 0, &rebuildNodeBudget) : nil;
            *migratedLegacyRule = YES;
        }

        if ([schema isKindOfClass:NSDictionary.class] || legacyPredicate != nil)
        {
            if (rebuilt)
            {
                group[@"AutoGroupRules"] = rebuilt;
            }
            else
            {
                // Unsupported rules stay disabled rather than being evaluated.
                [group removeObjectForKey:@"AutoGroupRules"];
                group[@"UsesAutoGroupRules"] = @(NO);
                NSLog(@"Transmission: discarded an auto-assign rule with an unsupported predicate structure");
            }
        }

        [validatedGroups addObject:group];
    }

    return validatedGroups;
}

- (void)saveGroups
{
    // Icons are transient, and predicates are stored only as validated schemas.
    NSMutableArray* groups = [NSMutableArray arrayWithCapacity:self.fGroups.count];
    for (NSDictionary* dict in self.fGroups)
    {
        NSMutableDictionary* tempDict = [dict mutableCopy];
        [tempDict removeObjectForKey:@"Icon"];

        NSPredicate* predicate = tempDict[@"AutoGroupRules"];
        if (predicate)
        {
            NSUInteger nodeBudget = kAutoGroupRuleMaxTotalNodes;
            NSDictionary* schema = safeSchemaFromAutoGroupPredicate(predicate, 0, &nodeBudget);
            if (schema)
            {
                tempDict[@"AutoGroupRulesSchema"] = schema;
            }
            else
            {
                [tempDict removeObjectForKey:@"AutoGroupRulesSchema"];
                tempDict[@"UsesAutoGroupRules"] = @(NO);
            }
            [tempDict removeObjectForKey:@"AutoGroupRules"];
        }

        [groups addObject:tempDict];
    }

    [NSUserDefaults.standardUserDefaults setObject:TRArchivedDataForObject(groups) forKey:@"GroupDicts"];
}

- (NSImage*)imageForGroupNone
{
    static NSImage* icon;
    if (icon)
    {
        return icon;
    }

    icon = [NSImage imageWithSize:NSMakeSize(kIconWidth, kIconWidth) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        //shape
        rect = NSInsetRect(rect, kBorderWidth / 2, kBorderWidth / 2);
        NSBezierPath* bp = [NSBezierPath bezierPathWithOvalInRect:rect];
        bp.lineWidth = kBorderWidth;

        //border
        // code reference for dashed style
        //CGFloat dashAndGapLength = M_PI * rect.size.width / 8;
        //CGFloat pattern[2] = { dashAndGapLength * .5, dashAndGapLength * .5 };
        //[bp setLineDash:pattern count:2 phase:0];

        [NSColor.controlTextColor setStroke];
        [bp stroke];

        return YES;
    }];
    [icon setTemplate:YES];

    return icon;
}

- (NSImage*)imageForGroup:(NSMutableDictionary*)dict
{
    NSImage* icon;
    if ((icon = dict[@"Icon"]))
    {
        return icon;
    }

    icon = [NSImage discIconWithColor:dict[@"Color"] insetFactor:0];

    dict[@"Icon"] = icon;

    return icon;
}

- (BOOL)torrent:(Torrent*)torrent doesMatchRulesForGroupAtIndex:(NSInteger)index
{
    if (![self usesAutoAssignRulesForIndex:index])
    {
        return NO;
    }

    // The predicate was rebuilt from validated data, so it needs no allowEvaluation.
    NSPredicate* predicate = [self autoAssignRulesForIndex:index];
    BOOL eval = NO;
    @try
    {
        eval = [predicate evaluateWithObject:torrent];
    }
    @catch (NSException* exception)
    {
        NSLog(@"Error when evaluating predicate (%@) - %@", predicate, exception);
    }
    @finally
    {
        return eval;
    }
}

@end
