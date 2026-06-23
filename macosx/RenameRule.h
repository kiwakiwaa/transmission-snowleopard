// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#import "ObjectiveCCompatibility.h"

typedef NS_ENUM(NSInteger, RenameRuleReplaceMode) {
    RenameRuleReplaceModeFirst = 0,
    RenameRuleReplaceModeLast = 1,
    RenameRuleReplaceModeAll = 2,
};

typedef NS_ENUM(NSInteger, RenameRuleTextPlacement) {
    RenameRuleTextPlacementReplace = 0,
    RenameRuleTextPlacementAppend = 1,
    RenameRuleTextPlacementPrepend = 2,
};

typedef NS_ENUM(NSInteger, RenameRuleCharacterRemovalMode) {
    RenameRuleCharacterRemovalModeFromStart = 0,
    RenameRuleCharacterRemovalModeFromEnd = 1,
    RenameRuleCharacterRemovalModeRange = 2,
};

typedef NS_ENUM(NSInteger, RenameRuleCaseMode) {
    RenameRuleCaseModeTitle = 0,
    RenameRuleCaseModeLower = 1,
    RenameRuleCaseModeUpper = 2,
};

@class RenameRuleConfig;
@class RenameRuleResult;

@protocol RenameRule<NSObject>

@property(nonatomic, copy, readonly) NSString* identifier;
@property(nonatomic, copy, readonly) NSString* localizedName;
@property(nonatomic, readonly) BOOL usesOrdering;

- (BOOL)validateConfig:(RenameRuleConfig*)config errorMessage:(NSString**)errorMessage;
- (RenameRuleResult*)previewNameForOriginalName:(NSString*)originalName
                                         config:(RenameRuleConfig*)config
                                       rowIndex:(NSUInteger)rowIndex;

@end

@interface RenameRuleConfig : NSObject<NSCopying>

@property(nonatomic, copy) NSString* searchText;
@property(nonatomic, copy) NSString* replacementText;
@property(nonatomic, copy) NSString* customText;
@property(nonatomic, copy) NSString* regexPattern;
@property(nonatomic, copy) NSString* regexReplacementText;
@property(nonatomic, copy) NSString* dateFormat;

@property(nonatomic) RenameRuleReplaceMode replaceMode;
@property(nonatomic) RenameRuleTextPlacement textPlacement;
@property(nonatomic) RenameRuleCharacterRemovalMode characterRemovalMode;
@property(nonatomic) RenameRuleCaseMode caseMode;
@property(nonatomic) NSInteger characterLocation;
@property(nonatomic) NSInteger characterCount;
@property(nonatomic) NSInteger sequenceStart;
@property(nonatomic) NSInteger sequenceDigits;

+ (instancetype)defaultConfig;

@end

@interface RenameRuleResult : NSObject

@property(nonatomic, copy) NSString* generatedName;
@property(nonatomic, copy) NSString* errorMessage;

+ (instancetype)resultWithGeneratedName:(NSString*)generatedName errorMessage:(NSString*)errorMessage;

@end
