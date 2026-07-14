// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.

#import "CocoaCompatibility.h"

// Tiger Foundation has no NSContainsPredicateOperatorType. Keep contains rules
// semantic and archivable there, then convert them to native comparisons when
// preferences move forward to Leopard or newer.
@interface TRLegacyContainsPredicate : NSPredicate<NSCoding>
{
  @private
    NSString* _keyPath;
    NSString* _value;
    NSComparisonPredicateModifier _modifier;
    NSUInteger _options;
}
- (instancetype)initWithKeyPath:(NSString*)keyPath
                           value:(NSString*)value
                        modifier:(NSComparisonPredicateModifier)modifier
                         options:(NSUInteger)options;
@property(nonatomic, readonly, copy) NSString* keyPath;
@property(nonatomic, readonly, copy) NSString* value;
@property(nonatomic, readonly) NSComparisonPredicateModifier modifier;
@property(nonatomic, readonly) NSUInteger options;
@end

NSPredicate* TRNativePredicateFromLegacyContainsPredicate(NSPredicate* predicate);

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

typedef NS_ENUM(NSInteger, NSRuleEditorRowType) {
    NSRuleEditorRowTypeSimple = 0,
    NSRuleEditorRowTypeCompound = 1,
};

typedef NS_ENUM(NSInteger, NSRuleEditorNestingMode) {
    NSRuleEditorNestingModeSingle = 0,
    NSRuleEditorNestingModeList = 1,
    NSRuleEditorNestingModeCompound = 2,
    NSRuleEditorNestingModeSimple = 3,
};

@interface NSPredicateEditorRowTemplate : NSObject<NSCoding, NSCopying>
{
  @private
    NSInteger _templateType;
    NSUInteger _options;
    NSComparisonPredicateModifier _modifier;
    NSUInteger _rightExpressionAttributeType;
    NSArray* _leftExpressions;
    NSArray* _rightExpressions;
    NSArray* _operators;
    NSArray* _compoundTypes;
    NSArray* _templateViews;
    NSExpression* _selectedLeftExpression;
    NSExpression* _selectedRightExpression;
    NSPredicateOperatorType _selectedOperator;
    NSCompoundPredicateType _selectedCompoundType;
}

- (instancetype)initWithCompoundTypes:(NSArray*)compoundTypes;
- (instancetype)initWithLeftExpressions:(NSArray*)leftExpressions
            rightExpressionAttributeType:(NSUInteger)attributeType
                                 modifier:(NSComparisonPredicateModifier)modifier
                                operators:(NSArray*)operators
                                  options:(NSUInteger)options;
- (instancetype)initWithLeftExpressions:(NSArray*)leftExpressions
                        rightExpressions:(NSArray*)rightExpressions
                                 modifier:(NSComparisonPredicateModifier)modifier
                                operators:(NSArray*)operators
                                  options:(NSUInteger)options;

- (NSArray*)compoundTypes;
- (NSArray*)leftExpressions;
- (NSArray*)rightExpressions;
- (NSArray*)operators;
- (NSUInteger)options;
- (NSComparisonPredicateModifier)modifier;
- (NSUInteger)rightExpressionAttributeType;
- (double)matchForPredicate:(NSPredicate*)predicate;
- (void)setPredicate:(NSPredicate*)predicate;
- (NSPredicate*)predicateWithSubpredicates:(NSArray*)subpredicates;
- (NSArray*)templateViews;

@end

@interface NSRuleEditor : NSControl
{
  @protected
    __unsafe_unretained id _ruleEditorDelegate;
    CGFloat _ruleEditorRowHeight;
    NSRuleEditorNestingMode _ruleEditorNestingMode;
    BOOL _canRemoveAllRows;
    BOOL _allowsEmptyCompoundRows;
    NSMutableIndexSet* _selectedRowIndexes;
}

@property(nonatomic, assign) id delegate;
@property(nonatomic) CGFloat rowHeight;
@property(nonatomic) NSRuleEditorNestingMode nestingMode;
@property(nonatomic) BOOL canRemoveAllRows;
@property(nonatomic, readonly) NSInteger numberOfRows;
@property(nonatomic, readonly, copy) NSIndexSet* selectedRowIndexes;

- (IBAction)addRow:(id)sender;
- (void)insertRowAtIndex:(NSInteger)rowIndex
                withType:(NSRuleEditorRowType)rowType
          asSubrowOfRow:(NSInteger)parentRow
                 animate:(BOOL)animate;
- (void)removeRowAtIndex:(NSInteger)rowIndex;
- (NSInteger)parentRowForRow:(NSInteger)rowIndex;
- (NSRuleEditorRowType)rowTypeForRow:(NSInteger)rowIndex;
- (NSArray*)criteriaForRow:(NSInteger)rowIndex;
- (NSArray*)displayValuesForRow:(NSInteger)rowIndex;
- (void)setCriteria:(NSArray*)criteria andDisplayValues:(NSArray*)values forRowAtIndex:(NSInteger)rowIndex;
- (void)selectRowIndexes:(NSIndexSet*)indexes byExtendingSelection:(BOOL)extend;

@end

@interface NSPredicateEditor : NSRuleEditor
{
  @private
    NSArray* _rowTemplates;
    NSMutableArray* _rootRows;
    NSPredicate* _predicate;
    BOOL _didFinishNibLoading;
    __unsafe_unretained id _predicateTarget;
    SEL _predicateAction;
}

@property(nonatomic, copy) NSArray* rowTemplates;
@property(nonatomic, retain) NSPredicate* objectValue;
@property(nonatomic, retain) NSPredicate* predicate;

- (IBAction)addGroup:(id)sender;
- (IBAction)removeRow:(id)sender;
- (void)reloadCriteria;
- (void)reloadPredicate;

@end

#endif
