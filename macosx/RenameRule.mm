// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "RenameRule.h"

@implementation RenameRuleConfig

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize searchText = _searchText;
@synthesize replacementText = _replacementText;
@synthesize customText = _customText;
@synthesize regexPattern = _regexPattern;
@synthesize regexReplacementText = _regexReplacementText;
@synthesize dateFormat = _dateFormat;
@synthesize replaceMode = _replaceMode;
@synthesize textPlacement = _textPlacement;
@synthesize characterRemovalMode = _characterRemovalMode;
@synthesize caseMode = _caseMode;
@synthesize characterLocation = _characterLocation;
@synthesize characterCount = _characterCount;
@synthesize sequenceStart = _sequenceStart;
@synthesize sequenceDigits = _sequenceDigits;
#endif

+ (instancetype)defaultConfig
{
    RenameRuleConfig* config = [[self alloc] init];
    config.searchText = @"";
    config.replacementText = @"";
    config.customText = @"";
    config.regexPattern = @"";
    config.regexReplacementText = @"";
    config.dateFormat = @"yyyy-MM-dd";
    config.replaceMode = RenameRuleReplaceModeAll;
    config.textPlacement = RenameRuleTextPlacementAppend;
    config.characterRemovalMode = RenameRuleCharacterRemovalModeFromStart;
    config.caseMode = RenameRuleCaseModeTitle;
    config.characterLocation = 1;
    config.characterCount = 1;
    config.sequenceStart = 1;
    config.sequenceDigits = 2;
    return config;
}

- (id)copyWithZone:(NSZone*)zone
{
    RenameRuleConfig* config = [[[self class] allocWithZone:zone] init];
    config.searchText = self.searchText;
    config.replacementText = self.replacementText;
    config.customText = self.customText;
    config.regexPattern = self.regexPattern;
    config.regexReplacementText = self.regexReplacementText;
    config.dateFormat = self.dateFormat;
    config.replaceMode = self.replaceMode;
    config.textPlacement = self.textPlacement;
    config.characterRemovalMode = self.characterRemovalMode;
    config.caseMode = self.caseMode;
    config.characterLocation = self.characterLocation;
    config.characterCount = self.characterCount;
    config.sequenceStart = self.sequenceStart;
    config.sequenceDigits = self.sequenceDigits;
    return config;
}

@end

@implementation RenameRuleResult

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize generatedName = _generatedName;
@synthesize errorMessage = _errorMessage;
#endif

+ (instancetype)resultWithGeneratedName:(NSString*)generatedName errorMessage:(NSString*)errorMessage
{
    RenameRuleResult* result = [[self alloc] init];
    result.generatedName = generatedName;
    result.errorMessage = errorMessage;
    return result;
}

@end
