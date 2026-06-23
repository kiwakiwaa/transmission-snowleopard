// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "RenameRules.h"

#import "CocoaCompatibility.h"

#include <libtransmission/macos-version.h>

@interface RenameBaseRule : NSObject<RenameRule>

@property(nonatomic, copy) NSString* identifier;
@property(nonatomic, copy) NSString* localizedName;
@property(nonatomic) BOOL usesOrdering;

- (instancetype)initWithIdentifier:(NSString*)identifier localizedName:(NSString*)localizedName usesOrdering:(BOOL)usesOrdering;

@end

@implementation RenameBaseRule

- (instancetype)initWithIdentifier:(NSString*)identifier localizedName:(NSString*)localizedName usesOrdering:(BOOL)usesOrdering
{
    if ((self = [super init]))
    {
        _identifier = [identifier copy];
        _localizedName = [localizedName copy];
        _usesOrdering = usesOrdering;
    }
    return self;
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    (void)config;
    (void)errorMessage;
    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)config;
    (void)rowIndex;
    return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
}

@end

@interface RenameReplaceRule : RenameBaseRule

@property(nonatomic) RenameRuleReplaceMode mode;

@end

@interface RenameAppendRule : RenameBaseRule
@end

@interface RenamePrependRule : RenameBaseRule
@end

@interface RenameDateRule : RenameBaseRule
@end

@interface RenameSequenceRule : RenameBaseRule
@end

@interface RenameCharacterRemovalRule : RenameBaseRule
@end

@interface RenameRegularExpressionRule : RenameBaseRule
@end

@interface RenameChangeCaseRule : RenameBaseRule
@end

static NSString* TRBatchRenameStringByPlacingString(NSString* originalName, NSString* string, RenameRuleTextPlacement placement)
{
    switch (placement)
    {
    case RenameRuleTextPlacementReplace:
    {
        NSString* extension = originalName.pathExtension;
        if (extension.length == 0 || [originalName isEqualToString:extension])
        {
            return string;
        }

        return [string stringByAppendingPathExtension:extension];
    }

    case RenameRuleTextPlacementAppend:
        return [originalName stringByAppendingString:string];

    case RenameRuleTextPlacementPrepend:
        return [string stringByAppendingString:originalName];
    }

    return originalName;
}

static NSString* TRBatchRenameBaseNameByRemovingExtension(NSString* originalName, NSString** extension)
{
    NSString* pathExtension = originalName.pathExtension;
    if (pathExtension.length == 0 || [originalName isEqualToString:pathExtension])
    {
        if (extension != nullptr)
        {
            *extension = @"";
        }
        return originalName;
    }

    if (extension != nullptr)
    {
        *extension = pathExtension;
    }
    return originalName.stringByDeletingPathExtension;
}

static NSString* TRBatchRenameNameByJoiningBaseNameAndExtension(NSString* baseName, NSString* extension)
{
    return extension.length > 0 ? [baseName stringByAppendingPathExtension:extension] : baseName;
}

@implementation RenameReplaceRule

- (instancetype)initWithMode:(RenameRuleReplaceMode)mode
{
    NSString* identifier = nil;
    NSString* localizedName = nil;

    switch (mode)
    {
    case RenameRuleReplaceModeFirst:
        identifier = @"replace-first";
        localizedName = NSLocalizedString(@"Replace First", "Batch rename rule");
        break;

    case RenameRuleReplaceModeLast:
        identifier = @"replace-last";
        localizedName = NSLocalizedString(@"Replace Last", "Batch rename rule");
        break;

    case RenameRuleReplaceModeAll:
        identifier = @"replace-all";
        localizedName = NSLocalizedString(@"Replace All", "Batch rename rule");
        break;
    }

    if ((self = [super initWithIdentifier:identifier localizedName:localizedName usesOrdering:NO]))
    {
        _mode = mode;
    }
    return self;
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    (void)config;
    (void)errorMessage;
    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    NSString* search = config.searchText;
    if (search.length == 0)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
    }

    NSString* generatedName = originalName;
    NSString* replacement = config.replacementText ?: @"";

    switch (self.mode)
    {
    case RenameRuleReplaceModeFirst:
    {
        NSRange range = [originalName rangeOfString:search];
        if (range.location != NSNotFound)
        {
            generatedName = [originalName stringByReplacingCharactersInRange:range withString:replacement];
        }
        break;
    }

    case RenameRuleReplaceModeLast:
    {
        NSRange range = [originalName rangeOfString:search options:NSBackwardsSearch];
        if (range.location != NSNotFound)
        {
            generatedName = [originalName stringByReplacingCharactersInRange:range withString:replacement];
        }
        break;
    }

    case RenameRuleReplaceModeAll:
        generatedName = [originalName stringByReplacingOccurrencesOfString:search withString:replacement];
        break;
    }

    return [RenameRuleResult resultWithGeneratedName:generatedName errorMessage:nil];
}

@end

@implementation RenameAppendRule

- (instancetype)init
{
    return [super initWithIdentifier:@"append" localizedName:NSLocalizedString(@"Append", "Batch rename rule") usesOrdering:NO];
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    (void)config;
    (void)errorMessage;
    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    if (config.customText.length == 0)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
    }
    return [RenameRuleResult resultWithGeneratedName:[originalName stringByAppendingString:config.customText] errorMessage:nil];
}

@end

@implementation RenamePrependRule

- (instancetype)init
{
    return [super initWithIdentifier:@"prepend" localizedName:NSLocalizedString(@"Prepend", "Batch rename rule") usesOrdering:NO];
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    (void)config;
    (void)errorMessage;
    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    if (config.customText.length == 0)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
    }
    return [RenameRuleResult resultWithGeneratedName:[config.customText stringByAppendingString:originalName] errorMessage:nil];
}

@end

@implementation RenameDateRule

- (instancetype)init
{
    return [super initWithIdentifier:@"date" localizedName:NSLocalizedString(@"Date", "Batch rename rule") usesOrdering:NO];
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    (void)config;
    (void)errorMessage;
    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    if (config.dateFormat.length == 0)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
    }

    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = config.dateFormat;
    NSString* dateString = [formatter stringFromDate:[NSDate date]];
    return [RenameRuleResult resultWithGeneratedName:TRBatchRenameStringByPlacingString(originalName, dateString, config.textPlacement)
                                       errorMessage:nil];
}

@end

@implementation RenameSequenceRule

- (instancetype)init
{
    return [super initWithIdentifier:@"sequence" localizedName:NSLocalizedString(@"Sequence", "Batch rename rule") usesOrdering:YES];
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    if (config.sequenceDigits < 1)
    {
        if (errorMessage != nullptr)
        {
            *errorMessage = NSLocalizedString(@"Digit count must be at least 1.", "Batch rename validation error");
        }
        return NO;
    }
    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    NSString* errorMessage = nil;
    if (![self validateConfig:config errorMessage:&errorMessage])
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:errorMessage];
    }

    NSInteger number = config.sequenceStart + (NSInteger)rowIndex;
    NSString* format = [NSString stringWithFormat:@"%%0%ldld", (long)config.sequenceDigits];
    NSString* sequence = [NSString stringWithFormat:format, (long)number];
    NSString* text = config.customText ?: @"";
    NSString* sequenceText = [text stringByAppendingString:sequence];
    return [RenameRuleResult resultWithGeneratedName:TRBatchRenameStringByPlacingString(originalName, sequenceText, config.textPlacement)
                                       errorMessage:nil];
}

@end

@implementation RenameCharacterRemovalRule

- (instancetype)init
{
    return [super initWithIdentifier:@"character-removal" localizedName:NSLocalizedString(@"Character Removal", "Batch rename rule") usesOrdering:NO];
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    if (config.characterCount < 1)
    {
        if (errorMessage != nullptr)
        {
            *errorMessage = NSLocalizedString(@"Character count must be at least 1.", "Batch rename validation error");
        }
        return NO;
    }

    if (config.characterRemovalMode == RenameRuleCharacterRemovalModeRange && config.characterLocation < 1)
    {
        if (errorMessage != nullptr)
        {
            *errorMessage = NSLocalizedString(@"Character position must be at least 1.", "Batch rename validation error");
        }
        return NO;
    }

    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    NSString* errorMessage = nil;
    if (![self validateConfig:config errorMessage:&errorMessage])
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:errorMessage];
    }

    NSString* extension = nil;
    NSString* baseName = TRBatchRenameBaseNameByRemovingExtension(originalName, &extension);
    NSUInteger length = baseName.length;
    if (length == 0)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
    }

    NSUInteger location = 0;
    NSUInteger count = MIN((NSUInteger)config.characterCount, length);

    switch (config.characterRemovalMode)
    {
    case RenameRuleCharacterRemovalModeFromStart:
        location = 0;
        break;

    case RenameRuleCharacterRemovalModeFromEnd:
        location = length - count;
        break;

    case RenameRuleCharacterRemovalModeRange:
        location = MIN((NSUInteger)config.characterLocation - 1, length);
        count = MIN(count, length - location);
        break;
    }

    NSString* newBaseName = [baseName stringByReplacingCharactersInRange:NSMakeRange(location, count) withString:@""];
    return [RenameRuleResult resultWithGeneratedName:TRBatchRenameNameByJoiningBaseNameAndExtension(newBaseName, extension) errorMessage:nil];
}

@end

@implementation RenameRegularExpressionRule

- (instancetype)init
{
    return [super initWithIdentifier:@"regular-expression" localizedName:NSLocalizedString(@"Regular Expression", "Batch rename rule") usesOrdering:NO];
}

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage
{
    if (![RenameRules regularExpressionRuleAvailable])
    {
        if (errorMessage != nullptr)
        {
            *errorMessage = NSLocalizedString(@"Regular expressions are unavailable.", "Batch rename validation error");
        }
        return NO;
    }

    if (config.regexPattern.length > 0)
    {
        NSError* error = nil;
        [NSRegularExpression regularExpressionWithPattern:config.regexPattern options:0 error:&error];
        if (error != nil)
        {
            if (errorMessage != nullptr)
            {
                *errorMessage = error.localizedDescription;
            }
            return NO;
        }
    }

    return YES;
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    NSString* errorMessage = nil;
    if (![self validateConfig:config errorMessage:&errorMessage])
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:errorMessage];
    }

    if (config.regexPattern.length == 0)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:nil];
    }

    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:config.regexPattern options:0 error:&error];
    if (regex == nil)
    {
        return [RenameRuleResult resultWithGeneratedName:originalName errorMessage:error.localizedDescription];
    }

    NSString* replacement = config.regexReplacementText ?: @"";
    NSString* generatedName = [regex stringByReplacingMatchesInString:originalName
                                                              options:0
                                                                range:NSMakeRange(0, originalName.length)
                                                         withTemplate:replacement];
    return [RenameRuleResult resultWithGeneratedName:generatedName errorMessage:nil];
}

@end

@implementation RenameChangeCaseRule

- (instancetype)init
{
    return [super initWithIdentifier:@"change-case" localizedName:NSLocalizedString(@"Change Case", "Batch rename rule") usesOrdering:NO];
}

- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex
{
    (void)rowIndex;

    NSString* generatedName = nil;
    switch (config.caseMode)
    {
    case RenameRuleCaseModeTitle:
        generatedName = originalName.capitalizedString;
        break;

    case RenameRuleCaseModeLower:
        generatedName = originalName.lowercaseString;
        break;

    case RenameRuleCaseModeUpper:
        generatedName = originalName.uppercaseString;
        break;
    }
    return [RenameRuleResult resultWithGeneratedName:generatedName errorMessage:nil];
}

@end

@implementation RenameRules

+ (id<RenameRule>)replaceRuleForMode:(RenameRuleReplaceMode)mode
{
    return [[RenameReplaceRule alloc] initWithMode:mode];
}

+ (id<RenameRule>)appendRule
{
    return [[RenameAppendRule alloc] init];
}

+ (id<RenameRule>)prependRule
{
    return [[RenamePrependRule alloc] init];
}

+ (id<RenameRule>)dateRule
{
    return [[RenameDateRule alloc] init];
}

+ (id<RenameRule>)sequenceRule
{
    return [[RenameSequenceRule alloc] init];
}

+ (id<RenameRule>)characterRemovalRule
{
    return [[RenameCharacterRemovalRule alloc] init];
}

+ (id<RenameRule>)regularExpressionRule
{
    return [[RenameRegularExpressionRule alloc] init];
}

+ (id<RenameRule>)changeCaseRule
{
    return [[RenameChangeCaseRule alloc] init];
}

+ (BOOL)regularExpressionRuleAvailable
{
#if TR_MACOS_SDK_BEFORE_10_7
    if (NSClassFromString(@"TRLegacyRegularExpression") != Nil)
    {
        return YES;
    }
#endif
    return NSClassFromString(@"NSRegularExpression") != Nil;
}

@end
