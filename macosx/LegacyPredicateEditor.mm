// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.

#import "LegacyPredicateEditor.h"

@implementation TRLegacyContainsPredicate

- (instancetype)initWithKeyPath:(NSString*)keyPath
                           value:(NSString*)value
                        modifier:(NSComparisonPredicateModifier)modifier
                         options:(NSUInteger)options
{
    if ((self = [super init]))
    {
        _keyPath = [keyPath copy];
        _value = [value copy];
        _modifier = modifier;
        _options = options;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
    return [self initWithKeyPath:[coder decodeObjectForKey:@"keyPath"]
                           value:[coder decodeObjectForKey:@"value"]
                        modifier:(NSComparisonPredicateModifier)[coder decodeIntForKey:@"modifier"]
                         options:(NSUInteger)[coder decodeIntForKey:@"options"]];
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeObject:_keyPath forKey:@"keyPath"];
    [coder encodeObject:_value forKey:@"value"];
    [coder encodeInt:(int)_modifier forKey:@"modifier"];
    [coder encodeInt:(int)_options forKey:@"options"];
}

- (NSString*)keyPath { return _keyPath; }
- (NSString*)value { return _value; }
- (NSComparisonPredicateModifier)modifier { return _modifier; }
- (NSUInteger)options { return _options; }

static NSString* TRStringByRemovingDiacritics(NSString* string)
{
    NSString* decomposed = [string decomposedStringWithCanonicalMapping];
    NSMutableString* result = [NSMutableString stringWithCapacity:[decomposed length]];
    NSCharacterSet* marks = [NSCharacterSet nonBaseCharacterSet];
    for (NSUInteger index = 0; index < [decomposed length]; ++index)
    {
        unichar character = [decomposed characterAtIndex:index];
        if (![marks characterIsMember:character])
        {
            [result appendFormat:@"%C", character];
        }
    }
    return result;
}

- (BOOL)tr_matchesValue:(id)candidate
{
    if (![candidate isKindOfClass:[NSString class]])
    {
        return NO;
    }
    NSString* haystack = candidate;
    NSString* needle = _value ?: @"";
    if ((_options & NSDiacriticInsensitivePredicateOption) != 0)
    {
        haystack = TRStringByRemovingDiacritics(haystack);
        needle = TRStringByRemovingDiacritics(needle);
    }
    unsigned searchOptions = (_options & NSCaseInsensitivePredicateOption) != 0 ? NSCaseInsensitiveSearch : 0;
    return [haystack rangeOfString:needle options:searchOptions].location != NSNotFound;
}

- (BOOL)evaluateWithObject:(id)object
{
    id candidate = [object valueForKeyPath:_keyPath];
    if (_modifier == NSAnyPredicateModifier && [candidate respondsToSelector:@selector(objectEnumerator)])
    {
        NSEnumerator* enumerator = [candidate objectEnumerator];
        id value = nil;
        while ((value = [enumerator nextObject]) != nil)
        {
            if ([self tr_matchesValue:value])
            {
                return YES;
            }
        }
        return NO;
    }
    return [self tr_matchesValue:candidate];
}

- (BOOL)evaluateWithObject:(id)object variableBindings:(NSDictionary*)bindings
{
    return [self evaluateWithObject:object];
}

- (NSPredicate*)predicateWithSubstitutionVariables:(NSDictionary*)variables
{
    return self;
}

- (NSString*)predicateFormat
{
    NSMutableString* escaped = [_value mutableCopy];
    [escaped replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, [escaped length])];
    NSString* modifier = _modifier == NSAnyPredicateModifier ? @"ANY " : @"";
    NSString* flags = _options == (NSCaseInsensitivePredicateOption | NSDiacriticInsensitivePredicateOption) ? @"[cd]" :
        (_options & NSCaseInsensitivePredicateOption) != 0 ? @"[c]" : @"";
    return [NSString stringWithFormat:@"%@%@ CONTAINS%@ \"%@\"", modifier, _keyPath, flags, escaped];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        return NO;
    }
    TRLegacyContainsPredicate* other = (TRLegacyContainsPredicate*)object;
    return [_keyPath isEqual:other.keyPath] && [_value isEqual:other.value] &&
        _modifier == other.modifier && _options == other.options;
}

- (NSUInteger)hash
{
    return [_keyPath hash] ^ [_value hash] ^ _modifier ^ _options;
}

- (id)copyWithZone:(NSZone*)zone
{
    return self;
}

@end

NSPredicate* TRNativePredicateFromLegacyContainsPredicate(NSPredicate* predicate)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    return predicate;
#else
    if ([predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        TRLegacyContainsPredicate* contains = (TRLegacyContainsPredicate*)predicate;
        return [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:contains.keyPath]
                                                   rightExpression:[NSExpression expressionForConstantValue:contains.value]
                                                          modifier:contains.modifier
                                                              type:NSContainsPredicateOperatorType
                                                           options:contains.options];
    }
    if ([predicate isKindOfClass:[NSCompoundPredicate class]])
    {
        NSCompoundPredicate* compound = (NSCompoundPredicate*)predicate;
        NSMutableArray* converted = [NSMutableArray array];
        for (NSPredicate* child in compound.subpredicates)
        {
            [converted addObject:TRNativePredicateFromLegacyContainsPredicate(child)];
        }
        if (compound.compoundPredicateType == NSOrPredicateType)
            return [NSCompoundPredicate orPredicateWithSubpredicates:converted];
        if (compound.compoundPredicateType == NSNotPredicateType)
            return [NSCompoundPredicate notPredicateWithSubpredicate:[converted objectAtIndex:0]];
        return [NSCompoundPredicate andPredicateWithSubpredicates:converted];
    }
    return predicate;
#endif
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

static NSString* const TRRowsDidChangeNotification = @"NSRuleEditorRowsDidChangeNotification";

@interface NSObject (TRRuleEditorDelegate)
- (void)ruleEditorRowsDidChange:(NSNotification*)notification;
@end

// Snow Leopard Interface Builder archives design-time rule rows using these
// AppKit-private classes. Tiger only needs decoding stand-ins. live
// rows are rebuilt below using public controls.
@interface _NSRuleEditorViewSliceHolder : NSView
@end
@implementation _NSRuleEditorViewSliceHolder
@end

@interface NSRuleEditorViewSliceRow : NSView
@end
@implementation NSRuleEditorViewSliceRow
@end

@interface NSRuleEditorButtonCell : NSButtonCell
@end
@implementation NSRuleEditorButtonCell
@end

@interface TRPredicateEditorButton : NSButton
@end

@implementation TRPredicateEditorButton

- (BOOL)isOpaque
{
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect circle = NSInsetRect([self bounds], 1.0, 1.0);
    NSBezierPath* bezel = [NSBezierPath bezierPathWithOvalInRect:circle];
    if ([[self cell] isHighlighted])
    {
        [[NSColor selectedControlColor] setFill];
    }
    else
    {
        [[NSColor controlColor] setFill];
    }
    [bezel fill];
    [[NSColor colorWithCalibratedWhite:0.62 alpha:1.0] setStroke];
    [bezel setLineWidth:1.0];
    [bezel stroke];

    NSColor* symbolColor = [self isEnabled] ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    [symbolColor setFill];
    CGFloat middleX = NSMidX([self bounds]);
    CGFloat middleY = NSMidY([self bounds]);
    NSRectFill(NSMakeRect((CGFloat)(NSInteger)(middleX - 4.0), (CGFloat)(NSInteger)(middleY - 0.5), 8.0, 1.0));
    if ([[self title] isEqualToString:@"+"])
    {
        NSRectFill(NSMakeRect((CGFloat)(NSInteger)(middleX - 0.5), (CGFloat)(NSInteger)(middleY - 4.0), 1.0, 8.0));
    }
}

@end

@interface TRCenteredPopUpButtonCell : NSPopUpButtonCell
@end

@implementation TRCenteredPopUpButtonCell

- (NSRect)titleRectForBounds:(NSRect)bounds
{
    NSRect titleRect = [super titleRectForBounds:bounds];
    titleRect.origin.y -= 1.0;
    return titleRect;
}

@end

@interface _NSRuleEditorViewUnboundRowHolder : NSObject<NSCoding>
@end
@implementation _NSRuleEditorViewUnboundRowHolder
- (instancetype)initWithCoder:(NSCoder*)coder
{
    return [super init];
}
- (void)encodeWithCoder:(NSCoder*)coder
{
}
@end

static NSArray* TRRepresentedObjectsFromPopUp(NSPopUpButton* popUp)
{
    NSMutableArray* result = [NSMutableArray array];
    NSEnumerator* enumerator = [[popUp itemArray] objectEnumerator];
    NSMenuItem* item = nil;
    while ((item = [enumerator nextObject]) != nil)
    {
        if ([item representedObject] != nil)
        {
            [result addObject:[item representedObject]];
        }
    }
    return result;
}

static NSPopUpButton* TRPopUpAtIndex(NSArray* views, NSUInteger index)
{
    NSUInteger found = 0;
    NSEnumerator* enumerator = [views objectEnumerator];
    id view = nil;
    while ((view = [enumerator nextObject]) != nil)
    {
        if ([view isKindOfClass:[NSPopUpButton class]])
        {
            if (found == index)
            {
                return view;
            }
            ++found;
        }
    }
    return nil;
}

@implementation NSPredicateEditorRowTemplate

- (instancetype)init
{
    return [self initWithCompoundTypes:[NSArray arrayWithObjects:
        [NSNumber numberWithInt:NSOrPredicateType],
        [NSNumber numberWithInt:NSAndPredicateType],
        [NSNumber numberWithInt:NSNotPredicateType], nil]];
}

- (instancetype)initWithCompoundTypes:(NSArray*)compoundTypes
{
    if ((self = [super init]))
    {
        _templateType = 2;
        _compoundTypes = [compoundTypes copy];
        _selectedCompoundType = (NSCompoundPredicateType)[[_compoundTypes objectAtIndex:0] intValue];
    }
    return self;
}

- (instancetype)initWithLeftExpressions:(NSArray*)leftExpressions
            rightExpressionAttributeType:(NSUInteger)attributeType
                                 modifier:(NSComparisonPredicateModifier)modifier
                                operators:(NSArray*)operators
                                  options:(NSUInteger)options
{
    if ((self = [super init]))
    {
        _templateType = 1;
        _leftExpressions = [leftExpressions copy];
        _rightExpressionAttributeType = attributeType;
        _modifier = modifier;
        _operators = [operators copy];
        _options = options;
        _selectedLeftExpression = [_leftExpressions count] != 0 ? [_leftExpressions objectAtIndex:0] : nil;
        _selectedRightExpression = [NSExpression expressionForConstantValue:@""];
        _selectedOperator = [_operators count] != 0 ? (NSPredicateOperatorType)[[_operators objectAtIndex:0] intValue] : NSEqualToPredicateOperatorType;
    }
    return self;
}

- (instancetype)initWithLeftExpressions:(NSArray*)leftExpressions
                        rightExpressions:(NSArray*)rightExpressions
                                 modifier:(NSComparisonPredicateModifier)modifier
                                operators:(NSArray*)operators
                                  options:(NSUInteger)options
{
    if ((self = [self initWithLeftExpressions:leftExpressions
                 rightExpressionAttributeType:0
                                      modifier:modifier
                                     operators:operators
                                       options:options]))
    {
        _rightExpressions = [rightExpressions copy];
        _selectedRightExpression = [_rightExpressions count] != 0 ? [_rightExpressions objectAtIndex:0] : nil;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
    if ((self = [super init]))
    {
        _templateType = [coder decodeIntForKey:@"NSPredicateTemplateType"];
        _options = (NSUInteger)[coder decodeIntForKey:@"NSPredicateTemplateOptions"];
        _modifier = (NSComparisonPredicateModifier)[coder decodeIntForKey:@"NSPredicateTemplateModifier"];
        _rightExpressionAttributeType = (NSUInteger)[coder decodeIntForKey:@"NSPredicateTemplateRightAttributeType"];
        _templateViews = [[coder decodeObjectForKey:@"NSPredicateTemplateViews"] copy];

        NSPopUpButton* first = TRPopUpAtIndex(_templateViews, 0);
        NSPopUpButton* second = TRPopUpAtIndex(_templateViews, 1);
        if (_templateType == 2)
        {
            _compoundTypes = [TRRepresentedObjectsFromPopUp(first) copy];
            _selectedCompoundType = [_compoundTypes count] != 0 ? (NSCompoundPredicateType)[[_compoundTypes objectAtIndex:0] intValue] : NSAndPredicateType;
        }
        else
        {
            _leftExpressions = [TRRepresentedObjectsFromPopUp(first) copy];
            _operators = [TRRepresentedObjectsFromPopUp(second) copy];
            if ([_leftExpressions count] == 0)
            {
                _leftExpressions = [[coder decodeObjectForKey:@"TRPredicateTemplateLeftExpressions"] copy];
            }
            if ([_operators count] == 0)
            {
                _operators = [[coder decodeObjectForKey:@"TRPredicateTemplateOperators"] copy];
            }
            _rightExpressions = [[coder decodeObjectForKey:@"TRPredicateTemplateRightExpressions"] copy];
            _selectedLeftExpression = [_leftExpressions count] != 0 ? [_leftExpressions objectAtIndex:0] : nil;
            _selectedRightExpression = [NSExpression expressionForConstantValue:@""];
            _selectedOperator = [_operators count] != 0 ? (NSPredicateOperatorType)[[_operators objectAtIndex:0] intValue] : NSEqualToPredicateOperatorType;
        }
        if (_templateType == 2 && [_compoundTypes count] == 0)
        {
            _compoundTypes = [[coder decodeObjectForKey:@"TRPredicateTemplateCompoundTypes"] copy];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeInt:(int)_templateType forKey:@"NSPredicateTemplateType"];
    [coder encodeInt:(int)_options forKey:@"NSPredicateTemplateOptions"];
    [coder encodeInt:(int)_modifier forKey:@"NSPredicateTemplateModifier"];
    [coder encodeInt:(int)_rightExpressionAttributeType forKey:@"NSPredicateTemplateRightAttributeType"];
    [coder encodeObject:_templateViews forKey:@"NSPredicateTemplateViews"];
    [coder encodeObject:_leftExpressions forKey:@"TRPredicateTemplateLeftExpressions"];
    [coder encodeObject:_rightExpressions forKey:@"TRPredicateTemplateRightExpressions"];
    [coder encodeObject:_operators forKey:@"TRPredicateTemplateOperators"];
    [coder encodeObject:_compoundTypes forKey:@"TRPredicateTemplateCompoundTypes"];
}

- (id)copyWithZone:(NSZone*)zone
{
    NSPredicateEditorRowTemplate* copy = nil;
    if (_templateType == 2)
    {
        copy = [[[self class] allocWithZone:zone] initWithCompoundTypes:_compoundTypes];
    }
    else if (_rightExpressions != nil)
    {
        copy = [[[self class] allocWithZone:zone] initWithLeftExpressions:_leftExpressions
                                                         rightExpressions:_rightExpressions
                                                                  modifier:_modifier
                                                                 operators:_operators
                                                                   options:_options];
    }
    else
    {
        copy = [[[self class] allocWithZone:zone] initWithLeftExpressions:_leftExpressions
                                             rightExpressionAttributeType:_rightExpressionAttributeType
                                                                  modifier:_modifier
                                                                 operators:_operators
                                                                   options:_options];
    }
    copy->_templateViews = [_templateViews copy];
    copy->_selectedLeftExpression = _selectedLeftExpression;
    copy->_selectedRightExpression = _selectedRightExpression;
    copy->_selectedOperator = _selectedOperator;
    copy->_selectedCompoundType = _selectedCompoundType;
    return copy;
}

- (NSArray*)compoundTypes { return _compoundTypes; }
- (NSArray*)leftExpressions { return _leftExpressions; }
- (NSArray*)rightExpressions { return _rightExpressions; }
- (NSArray*)operators { return _operators; }
- (NSUInteger)options { return _options; }
- (NSComparisonPredicateModifier)modifier { return _modifier; }
- (NSUInteger)rightExpressionAttributeType { return _rightExpressionAttributeType; }
- (NSArray*)templateViews { return _templateViews; }

- (double)matchForPredicate:(NSPredicate*)predicate
{
    if (_templateType == 2)
    {
        if (![predicate isKindOfClass:[NSCompoundPredicate class]])
        {
            return 0.0;
        }
        NSCompoundPredicateType type = [(NSCompoundPredicate*)predicate compoundPredicateType];
        return [_compoundTypes containsObject:[NSNumber numberWithInt:(int)type]] ? 1.0 : 0.0;
    }
    if ([predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        TRLegacyContainsPredicate* contains = (TRLegacyContainsPredicate*)predicate;
        NSExpression* left = [NSExpression expressionForKeyPath:contains.keyPath];
        return [_leftExpressions containsObject:left] && [_operators containsObject:[NSNumber numberWithInt:99]] ? 1.0 : 0.0;
    }
    if (![predicate isKindOfClass:[NSComparisonPredicate class]])
    {
        return 0.0;
    }
    NSComparisonPredicate* comparison = (NSComparisonPredicate*)predicate;
    if (![_leftExpressions containsObject:[comparison leftExpression]])
    {
        return 0.0;
    }
    double quality = 0.75;
    if ([_operators containsObject:[NSNumber numberWithInt:(int)[comparison predicateOperatorType]]])
    {
        quality += 0.15;
    }
    if ([comparison options] == _options)
    {
        quality += 0.1;
    }
    return quality;
}

- (void)setPredicate:(NSPredicate*)predicate
{
    if (_templateType == 2 && [predicate isKindOfClass:[NSCompoundPredicate class]])
    {
        _selectedCompoundType = [(NSCompoundPredicate*)predicate compoundPredicateType];
    }
    else if (_templateType == 1 && [predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        TRLegacyContainsPredicate* contains = (TRLegacyContainsPredicate*)predicate;
        _selectedLeftExpression = [NSExpression expressionForKeyPath:contains.keyPath];
        _selectedRightExpression = [NSExpression expressionForConstantValue:contains.value];
        _selectedOperator = (NSPredicateOperatorType)99;
    }
    else if (_templateType == 1 && [predicate isKindOfClass:[NSComparisonPredicate class]])
    {
        NSComparisonPredicate* comparison = (NSComparisonPredicate*)predicate;
        _selectedLeftExpression = [comparison leftExpression];
        _selectedRightExpression = [comparison rightExpression];
        _selectedOperator = [comparison predicateOperatorType];
    }
}

- (NSPredicate*)predicateWithSubpredicates:(NSArray*)subpredicates
{
    if (_templateType == 2)
    {
        if (_selectedCompoundType == NSOrPredicateType)
        {
            return [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
        }
        if (_selectedCompoundType == NSNotPredicateType)
        {
            return [NSCompoundPredicate notPredicateWithSubpredicate:
                [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates]];
        }
        return [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    }

    NSExpression* right = _selectedRightExpression;
    if (right == nil)
    {
        right = [NSExpression expressionForConstantValue:@""];
    }
    if ((int)_selectedOperator == 99)
    {
        return [[TRLegacyContainsPredicate alloc] initWithKeyPath:[_selectedLeftExpression keyPath]
            value:[_selectedRightExpression constantValue] modifier:_modifier options:_options];
    }
    return [NSComparisonPredicate predicateWithLeftExpression:_selectedLeftExpression
                                              rightExpression:right
                                                     modifier:_modifier
                                                         type:_selectedOperator
                                                      options:_options];
}

@end


@interface TRPredicateEditorRow : NSObject
{
  @public
    NSPredicateEditorRowTemplate* rowTemplate;
    NSMutableArray* children;
    __unsafe_unretained TRPredicateEditorRow* parent;
}
@end

@implementation TRPredicateEditorRow
- (instancetype)init
{
    if ((self = [super init]))
    {
        children = [NSMutableArray array];
    }
    return self;
}
@end

// AppKit merges every row template into a criterion tree. A selected leaf
// identifies the template that owns the complete path through the popups.
@interface TRPredicateEditorCriterionNode : NSObject
{
  @public
    NSString* title;
    id representedObject;
    NSPredicateEditorRowTemplate* rowTemplate;
    NSMutableArray* children;
}
@end

@implementation TRPredicateEditorCriterionNode
- (instancetype)init
{
    if ((self = [super init]))
    {
        children = [NSMutableArray array];
    }
    return self;
}
@end

@interface NSPredicateEditor ()<NSTextFieldDelegate>
- (NSArray*)tr_flatRows;
- (NSPredicate*)tr_currentPredicate;
- (void)tr_rebuildViews;
- (void)tr_sendAction;
- (void)tr_rowsChangedSendingAction:(BOOL)sendAction;
@end

@implementation NSRuleEditor

@synthesize delegate = _ruleEditorDelegate;
@synthesize rowHeight = _ruleEditorRowHeight;
@synthesize nestingMode = _ruleEditorNestingMode;
@synthesize canRemoveAllRows = _canRemoveAllRows;

- (instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        _ruleEditorRowHeight = 25.0;
        _ruleEditorNestingMode = NSRuleEditorNestingModeCompound;
        _selectedRowIndexes = [NSMutableIndexSet indexSet];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        _ruleEditorRowHeight = [coder decodeDoubleForKey:@"NSRuleEditorSliceHeight"];
        if (_ruleEditorRowHeight <= 0.0)
        {
            _ruleEditorRowHeight = 25.0;
        }
        _ruleEditorNestingMode = (NSRuleEditorNestingMode)[coder decodeIntForKey:@"NSRuleEditorNestingMode"];
        _canRemoveAllRows = ![coder decodeBoolForKey:@"NSRuleEditorDisallowEmpty"];
        _allowsEmptyCompoundRows = [coder decodeBoolForKey:@"NSRuleEditorAllowsEmptyCompoundRows"];
        _selectedRowIndexes = [NSMutableIndexSet indexSet];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_ruleEditorRowHeight forKey:@"NSRuleEditorSliceHeight"];
    [coder encodeInt:(int)_ruleEditorNestingMode forKey:@"NSRuleEditorNestingMode"];
    [coder encodeBool:!_canRemoveAllRows forKey:@"NSRuleEditorDisallowEmpty"];
    [coder encodeBool:_allowsEmptyCompoundRows forKey:@"NSRuleEditorAllowsEmptyCompoundRows"];
}

- (NSInteger)numberOfRows { return 0; }
- (NSIndexSet*)selectedRowIndexes { return [_selectedRowIndexes copy]; }
- (IBAction)addRow:(id)sender {}
- (void)insertRowAtIndex:(NSInteger)rowIndex withType:(NSRuleEditorRowType)rowType asSubrowOfRow:(NSInteger)parentRow animate:(BOOL)animate {}
- (void)removeRowAtIndex:(NSInteger)rowIndex {}
- (NSInteger)parentRowForRow:(NSInteger)rowIndex { return -1; }
- (NSRuleEditorRowType)rowTypeForRow:(NSInteger)rowIndex { return NSRuleEditorRowTypeSimple; }
- (NSArray*)criteriaForRow:(NSInteger)rowIndex { return nil; }
- (NSArray*)displayValuesForRow:(NSInteger)rowIndex { return nil; }
- (void)setCriteria:(NSArray*)criteria andDisplayValues:(NSArray*)values forRowAtIndex:(NSInteger)rowIndex {}

- (void)selectRowIndexes:(NSIndexSet*)indexes byExtendingSelection:(BOOL)extend
{
    if (!extend)
    {
        [_selectedRowIndexes removeAllIndexes];
    }
    [_selectedRowIndexes addIndexes:indexes];
    [self setNeedsDisplay:YES];
}

@end


static void TRAppendRows(NSArray* source, NSMutableArray* rows, NSMutableArray* depths, NSUInteger depth)
{
    NSEnumerator* enumerator = [source objectEnumerator];
    TRPredicateEditorRow* row = nil;
    while ((row = [enumerator nextObject]) != nil)
    {
        [rows addObject:row];
        if (depths != nil)
        {
            [depths addObject:[NSNumber numberWithInt:(int)depth]];
        }
        TRAppendRows(row->children, rows, depths, depth + 1);
    }
}

static BOOL TREqualCriterionTitles(NSString* first, NSString* second)
{
    return first == second || [first isEqualToString:second];
}

static TRPredicateEditorCriterionNode* TRCriterionNodeWithTitle(NSArray* nodes, NSString* title)
{
    NSEnumerator* enumerator = [nodes objectEnumerator];
    TRPredicateEditorCriterionNode* node = nil;
    while ((node = [enumerator nextObject]) != nil)
    {
        if (TREqualCriterionTitles(node->title, title))
        {
            return node;
        }
    }
    return nil;
}

static void TRMergeCriterionNodes(NSMutableArray* destination, NSArray* source)
{
    NSEnumerator* enumerator = [source objectEnumerator];
    TRPredicateEditorCriterionNode* sourceNode = nil;
    while ((sourceNode = [enumerator nextObject]) != nil)
    {
        TRPredicateEditorCriterionNode* destinationNode = TRCriterionNodeWithTitle(destination, sourceNode->title);
        if (destinationNode == nil)
        {
            [destination addObject:sourceNode];
        }
        else
        {
            TRMergeCriterionNodes(destinationNode->children, sourceNode->children);
        }
    }
}

static NSArray* TRCriterionNodesForTemplateViews(
    NSArray* views, NSUInteger viewIndex, NSPredicateEditorRowTemplate* rowTemplate)
{
    if (viewIndex >= [views count])
    {
        return [NSArray array];
    }

    id view = [views objectAtIndex:viewIndex];
    NSMutableArray* nodes = [NSMutableArray array];
    if ([view isKindOfClass:[NSPopUpButton class]])
    {
        NSEnumerator* enumerator = [[view itemArray] objectEnumerator];
        NSMenuItem* item = nil;
        while ((item = [enumerator nextObject]) != nil)
        {
            TRPredicateEditorCriterionNode* node = [[TRPredicateEditorCriterionNode alloc] init];
            node->title = [item isSeparatorItem] ? @"\n---" : [item title];
            node->representedObject = [item representedObject];
            node->rowTemplate = rowTemplate;
            [node->children addObjectsFromArray:TRCriterionNodesForTemplateViews(views, viewIndex + 1, rowTemplate)];
            [nodes addObject:node];
        }
    }
    else
    {
        TRPredicateEditorCriterionNode* node = [[TRPredicateEditorCriterionNode alloc] init];
        node->rowTemplate = rowTemplate;
        [node->children addObjectsFromArray:TRCriterionNodesForTemplateViews(views, viewIndex + 1, rowTemplate)];
        [nodes addObject:node];
    }
    return nodes;
}

static NSArray* TRMergedCriterionTree(NSArray* rowTemplates, BOOL compound)
{
    NSMutableArray* roots = [NSMutableArray array];
    NSEnumerator* enumerator = [rowTemplates objectEnumerator];
    NSPredicateEditorRowTemplate* rowTemplate = nil;
    while ((rowTemplate = [enumerator nextObject]) != nil)
    {
        if (([[rowTemplate compoundTypes] count] != 0) != compound)
        {
            continue;
        }
        TRMergeCriterionNodes(roots, TRCriterionNodesForTemplateViews([rowTemplate templateViews], 0, rowTemplate));
    }
    return roots;
}

static TRPredicateEditorCriterionNode* TRCriterionNodeForRepresentedObject(NSArray* nodes, id representedObject)
{
    NSEnumerator* enumerator = [nodes objectEnumerator];
    TRPredicateEditorCriterionNode* node = nil;
    while ((node = [enumerator nextObject]) != nil)
    {
        if (node->representedObject == representedObject || [node->representedObject isEqual:representedObject])
        {
            return node;
        }
        TRPredicateEditorCriterionNode* child = TRCriterionNodeForRepresentedObject(node->children, representedObject);
        if (child != nil)
        {
            return child;
        }
    }
    return nil;
}

static NSCompoundPredicateType TRNormalizedCompoundType(NSCompoundPredicate* predicate, NSArray** subpredicates)
{
    NSCompoundPredicateType type = [predicate compoundPredicateType];
    *subpredicates = [predicate subpredicates];
    if (type == NSNotPredicateType && [*subpredicates count] == 1)
    {
        id inner = [*subpredicates objectAtIndex:0];
        if ([inner isKindOfClass:[NSCompoundPredicate class]] && [inner compoundPredicateType] == NSOrPredicateType)
        {
            *subpredicates = [inner subpredicates];
        }
    }
    return type;
}

static NSExpression* TRLeftExpressionForPredicate(NSPredicate* predicate)
{
    if ([predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        return [NSExpression expressionForKeyPath:[(TRLegacyContainsPredicate*)predicate keyPath]];
    }
    return [(NSComparisonPredicate*)predicate leftExpression];
}

static NSExpression* TRRightExpressionForPredicate(NSPredicate* predicate)
{
    if ([predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        return [NSExpression expressionForConstantValue:[(TRLegacyContainsPredicate*)predicate value]];
    }
    return [(NSComparisonPredicate*)predicate rightExpression];
}

static NSPredicateOperatorType TROperatorForPredicate(NSPredicate* predicate)
{
    return [predicate isKindOfClass:[TRLegacyContainsPredicate class]] ? (NSPredicateOperatorType)99 :
        [(NSComparisonPredicate*)predicate predicateOperatorType];
}

@implementation NSPredicateEditor

@synthesize rowTemplates = _rowTemplates;

- (id)target { return _predicateTarget; }
- (void)setTarget:(id)target { _predicateTarget = target; }
- (SEL)action { return _predicateAction; }
- (void)setAction:(SEL)action { _predicateAction = action; }

- (instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        _rootRows = [NSMutableArray array];
        _didFinishNibLoading = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        _rootRows = [NSMutableArray array];
        self.rowTemplates = [coder decodeObjectForKey:@"NSPredicateTemplates"];
        NSString* actionName = [coder decodeObjectForKey:@"NSPredicateAction"];
        if (actionName != nil)
        {
            [self setAction:NSSelectorFromString(actionName)];
        }
        [self setTarget:[coder decodeObjectForKey:@"NSPredicateTarget"]];
        NSPredicate* archivedPredicate = [coder decodeObjectForKey:@"NSPredicateEditorPredicate"];
        _predicate = nil;
        self.objectValue = archivedPredicate;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_rowTemplates forKey:@"NSPredicateTemplates"];
    if ([self target] != nil)
    {
        [coder encodeConditionalObject:[self target] forKey:@"NSPredicateTarget"];
    }
    if ([self action] != NULL)
    {
        [coder encodeObject:NSStringFromSelector([self action]) forKey:@"NSPredicateAction"];
    }
    [coder encodeObject:[self objectValue] forKey:@"NSPredicateEditorPredicate"];
}

- (void)awakeFromNib
{
    _didFinishNibLoading = YES;
    NSPredicate* archivedPredicate = _predicate;
    _predicate = nil;
    self.objectValue = archivedPredicate;
}

- (BOOL)isFlipped { return YES; }

- (void)setRowTemplates:(NSArray*)templates
{
    _rowTemplates = [templates copy];
    if (_didFinishNibLoading)
    {
        [self reloadCriteria];
    }
}

- (NSArray*)tr_flatRows
{
    NSMutableArray* rows = [NSMutableArray array];
    TRAppendRows(_rootRows, rows, nil, 0);
    return rows;
}

- (NSInteger)numberOfRows
{
    return (NSInteger)[[self tr_flatRows] count];
}

- (TRPredicateEditorRow*)tr_rowAtIndex:(NSInteger)index
{
    NSArray* rows = [self tr_flatRows];
    return index >= 0 && index < (NSInteger)[rows count] ? [rows objectAtIndex:index] : nil;
}

- (NSPredicateEditorRowTemplate*)tr_bestTemplateForPredicate:(NSPredicate*)predicate
{
    NSPredicateEditorRowTemplate* best = nil;
    double bestQuality = 0.0;
    NSEnumerator* enumerator = [_rowTemplates objectEnumerator];
    NSPredicateEditorRowTemplate* candidate = nil;
    while ((candidate = [enumerator nextObject]) != nil)
    {
        double quality = [candidate matchForPredicate:predicate];
        if (quality > bestQuality)
        {
            best = candidate;
            bestQuality = quality;
        }
    }
    return best;
}

- (TRPredicateEditorRow*)tr_rowFromPredicate:(NSPredicate*)predicate parent:(TRPredicateEditorRow*)parent
{
    NSPredicateEditorRowTemplate* sourceTemplate = [self tr_bestTemplateForPredicate:predicate];
    if (sourceTemplate == nil)
    {
        return nil;
    }
    TRPredicateEditorRow* row = [[TRPredicateEditorRow alloc] init];
    row->parent = parent;
    row->rowTemplate = [sourceTemplate copy];
    [row->rowTemplate setPredicate:predicate];
    if ([predicate isKindOfClass:[NSCompoundPredicate class]])
    {
        NSArray* subpredicates = nil;
        TRNormalizedCompoundType((NSCompoundPredicate*)predicate, &subpredicates);
        NSEnumerator* enumerator = [subpredicates objectEnumerator];
        NSPredicate* childPredicate = nil;
        while ((childPredicate = [enumerator nextObject]) != nil)
        {
            TRPredicateEditorRow* child = [self tr_rowFromPredicate:childPredicate parent:row];
            if (child != nil)
            {
                [row->children addObject:child];
            }
        }
    }
    return row;
}

- (NSPredicate*)tr_predicateFromRow:(TRPredicateEditorRow*)row
{
    NSMutableArray* subpredicates = [NSMutableArray array];
    NSEnumerator* enumerator = [row->children objectEnumerator];
    TRPredicateEditorRow* child = nil;
    while ((child = [enumerator nextObject]) != nil)
    {
        NSPredicate* predicate = [self tr_predicateFromRow:child];
        if (predicate != nil)
        {
            [subpredicates addObject:predicate];
        }
    }
    return [row->rowTemplate predicateWithSubpredicates:subpredicates];
}

- (NSPredicate*)objectValue
{
    [self validateEditing];
    return [self tr_currentPredicate];
}

- (NSPredicate*)tr_currentPredicate
{
    if ([_rootRows count] == 0)
    {
        return nil;
    }
    if ([_rootRows count] == 1)
    {
        return [self tr_predicateFromRow:[_rootRows objectAtIndex:0]];
    }
    NSMutableArray* predicates = [NSMutableArray array];
    NSEnumerator* enumerator = [_rootRows objectEnumerator];
    TRPredicateEditorRow* row = nil;
    while ((row = [enumerator nextObject]) != nil)
    {
        [predicates addObject:[self tr_predicateFromRow:row]];
    }
    return [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
}

- (void)setObjectValue:(NSPredicate*)predicate
{
    if ((_predicate == nil && predicate == nil) || [_predicate isEqual:predicate])
    {
        if (_didFinishNibLoading)
        {
            [self tr_rebuildViews];
        }
        return;
    }
    _predicate = predicate;
    [_rootRows removeAllObjects];
    if (predicate != nil)
    {
        TRPredicateEditorRow* row = [self tr_rowFromPredicate:predicate parent:nil];
        if (row != nil)
        {
            [_rootRows addObject:row];
        }
    }
    [_selectedRowIndexes removeAllIndexes];
    if (_didFinishNibLoading)
    {
        [self tr_rowsChangedSendingAction:NO];
    }
}

- (NSPredicate*)predicate { return [self objectValue]; }
- (void)setPredicate:(NSPredicate*)predicate { self.objectValue = predicate; }

- (NSPredicateEditorRowTemplate*)tr_defaultTemplateForType:(NSRuleEditorRowType)type
{
    NSEnumerator* enumerator = [_rowTemplates objectEnumerator];
    NSPredicateEditorRowTemplate* candidate = nil;
    while ((candidate = [enumerator nextObject]) != nil)
    {
        BOOL compound = [[candidate compoundTypes] count] != 0;
        if ((type == NSRuleEditorRowTypeCompound) == compound)
        {
            return candidate;
        }
    }
    return nil;
}

- (TRPredicateEditorRow*)tr_newRowOfType:(NSRuleEditorRowType)type parent:(TRPredicateEditorRow*)parent
{
    NSPredicateEditorRowTemplate* source = [self tr_defaultTemplateForType:type];
    if (source == nil)
    {
        return nil;
    }
    TRPredicateEditorRow* row = [[TRPredicateEditorRow alloc] init];
    row->parent = parent;
    row->rowTemplate = [source copy];
    return row;
}

- (void)insertRowAtIndex:(NSInteger)rowIndex
                withType:(NSRuleEditorRowType)rowType
          asSubrowOfRow:(NSInteger)parentRowIndex
                 animate:(BOOL)animate
{
    TRPredicateEditorRow* parentRow = [self tr_rowAtIndex:parentRowIndex];
    TRPredicateEditorRow* row = [self tr_newRowOfType:rowType parent:parentRow];
    if (row == nil)
    {
        return;
    }
    NSMutableArray* siblings = parentRow != nil ? parentRow->children : _rootRows;
    NSUInteger insertion = [siblings count];
    if (rowIndex >= 0)
    {
        TRPredicateEditorRow* following = [self tr_rowAtIndex:rowIndex];
        NSUInteger candidate = [siblings indexOfObjectIdenticalTo:following];
        if (candidate != NSNotFound)
        {
            insertion = candidate;
        }
    }
    [siblings insertObject:row atIndex:insertion];
    [self tr_rowsChangedSendingAction:YES];
}

- (NSInteger)tr_contextRowFromSender:(id)sender
{
    if ([sender respondsToSelector:@selector(tag)] && [sender tag] >= 0)
    {
        return [sender tag] / 10;
    }
    return [_selectedRowIndexes count] != 0 ? (NSInteger)[_selectedRowIndexes firstIndex] : -1;
}

- (IBAction)addRow:(id)sender
{
    NSInteger const rowCount = [self numberOfRows];
    if (_ruleEditorNestingMode == NSRuleEditorNestingModeList)
    {
        [self insertRowAtIndex:rowCount withType:NSRuleEditorRowTypeSimple asSubrowOfRow:-1 animate:NO];
        return;
    }
    if (_ruleEditorNestingMode == NSRuleEditorNestingModeSingle)
    {
        if (rowCount == 0)
        {
            [self insertRowAtIndex:0 withType:NSRuleEditorRowTypeSimple asSubrowOfRow:-1 animate:NO];
        }
        else
        {
            NSBeep();
        }
        return;
    }
    if (rowCount != 0)
    {
        [self insertRowAtIndex:rowCount withType:NSRuleEditorRowTypeSimple asSubrowOfRow:0 animate:NO];
        return;
    }

    // AppKit performs these as one add-row transaction: compound root first,
    // then its required simple child. Build both before notifying observers so
    // they never see a temporarily empty compound predicate.
    TRPredicateEditorRow* root = [self tr_newRowOfType:NSRuleEditorRowTypeCompound parent:nil];
    TRPredicateEditorRow* child = [self tr_newRowOfType:NSRuleEditorRowTypeSimple parent:root];
    if (root != nil && child != nil)
    {
        [root->children addObject:child];
        [_rootRows addObject:root];
        [self tr_rowsChangedSendingAction:YES];
    }
}

- (void)tr_addSimpleRowFromSender:(id)sender
{
    NSInteger selectedIndex = [self tr_contextRowFromSender:sender];
    TRPredicateEditorRow* selected = [self tr_rowAtIndex:selectedIndex];
    TRPredicateEditorRow* parent = nil;
    if (selected != nil)
    {
        parent = [[selected->rowTemplate compoundTypes] count] != 0 ? selected : selected->parent;
    }
    NSInteger parentIndex = parent != nil ? [[self tr_flatRows] indexOfObjectIdenticalTo:parent] : -1;
    [self insertRowAtIndex:-1 withType:NSRuleEditorRowTypeSimple asSubrowOfRow:parentIndex animate:NO];
}

- (IBAction)addGroup:(id)sender
{
    NSInteger selectedIndex = [self tr_contextRowFromSender:sender];
    TRPredicateEditorRow* selected = [self tr_rowAtIndex:selectedIndex];
    TRPredicateEditorRow* parent = nil;
    if (selected != nil)
    {
        parent = [[selected->rowTemplate compoundTypes] count] != 0 ? selected : selected->parent;
    }
    TRPredicateEditorRow* group = [self tr_newRowOfType:NSRuleEditorRowTypeCompound parent:parent];
    TRPredicateEditorRow* child = [self tr_newRowOfType:NSRuleEditorRowTypeSimple parent:group];
    if (group != nil && child != nil)
    {
        [group->children addObject:child];
        NSMutableArray* siblings = parent != nil ? parent->children : _rootRows;
        [siblings addObject:group];
        [self tr_rowsChangedSendingAction:YES];
    }
}

- (BOOL)tr_canRemoveRow:(TRPredicateEditorRow*)row
{
    if (row == nil)
    {
        return NO;
    }
    if (row->parent != nil && [row->parent->children count] == 1 && !_allowsEmptyCompoundRows)
    {
        return NO;
    }
    NSMutableArray* siblings = row->parent != nil ? row->parent->children : _rootRows;
    if (row->parent == nil && [siblings count] == 1 && !_canRemoveAllRows)
    {
        return NO;
    }
    return YES;
}

- (void)removeRowAtIndex:(NSInteger)rowIndex
{
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    if (![self tr_canRemoveRow:row])
    {
        return;
    }
    NSMutableArray* siblings = row->parent != nil ? row->parent->children : _rootRows;
    [siblings removeObjectIdenticalTo:row];
    [_selectedRowIndexes removeAllIndexes];
    [self tr_rowsChangedSendingAction:YES];
}

- (IBAction)removeRow:(id)sender
{
    NSInteger row = [self tr_contextRowFromSender:sender];
    if (row >= 0)
    {
        [self removeRowAtIndex:row];
    }
}

- (NSInteger)parentRowForRow:(NSInteger)rowIndex
{
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    return row != nil && row->parent != nil ? [[self tr_flatRows] indexOfObjectIdenticalTo:row->parent] : -1;
}

- (NSRuleEditorRowType)rowTypeForRow:(NSInteger)rowIndex
{
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    return row != nil && [[row->rowTemplate compoundTypes] count] != 0 ? NSRuleEditorRowTypeCompound : NSRuleEditorRowTypeSimple;
}

- (NSArray*)criteriaForRow:(NSInteger)rowIndex
{
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    if (row == nil)
    {
        return nil;
    }
    if ([[row->rowTemplate compoundTypes] count] != 0)
    {
        return [NSArray arrayWithObjects:[row->rowTemplate compoundTypes], @"of the following are true", nil];
    }
    return [NSArray arrayWithObjects:[row->rowTemplate leftExpressions], [row->rowTemplate operators], @"value", nil];
}

- (NSArray*)displayValuesForRow:(NSInteger)rowIndex
{
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    if (row == nil)
    {
        return nil;
    }
    NSPredicate* predicate = [self tr_predicateFromRow:row];
    if ([predicate isKindOfClass:[NSComparisonPredicate class]] || [predicate isKindOfClass:[TRLegacyContainsPredicate class]])
    {
        return [NSArray arrayWithObjects:TRLeftExpressionForPredicate(predicate),
            [NSNumber numberWithInt:(int)TROperatorForPredicate(predicate)],
            [TRRightExpressionForPredicate(predicate) constantValue] ?: @"", nil];
    }
    NSArray* ignored = nil;
    return [NSArray arrayWithObject:[NSNumber numberWithInt:(int)TRNormalizedCompoundType((NSCompoundPredicate*)predicate, &ignored)]];
}

- (void)setCriteria:(NSArray*)criteria andDisplayValues:(NSArray*)values forRowAtIndex:(NSInteger)rowIndex
{
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    if (row == nil || [values count] == 0)
    {
        return;
    }
    NSPredicate* predicate = nil;
    if ([[row->rowTemplate compoundTypes] count] != 0)
    {
        NSCompoundPredicateType type = (NSCompoundPredicateType)[[values objectAtIndex:0] intValue];
        NSArray* currentChildren = [(NSCompoundPredicate*)[self tr_predicateFromRow:row] subpredicates];
        if (type == NSOrPredicateType)
            predicate = [NSCompoundPredicate orPredicateWithSubpredicates:currentChildren];
        else if (type == NSNotPredicateType)
            predicate = [NSCompoundPredicate notPredicateWithSubpredicate:[NSCompoundPredicate orPredicateWithSubpredicates:currentChildren]];
        else
            predicate = [NSCompoundPredicate andPredicateWithSubpredicates:currentChildren];
    }
    else if ([values count] >= 3)
    {
        NSExpression* left = [values objectAtIndex:0];
        NSExpression* right = [[values objectAtIndex:2] isKindOfClass:[NSExpression class]] ? [values objectAtIndex:2] :
            [NSExpression expressionForConstantValue:[values objectAtIndex:2]];
        NSPredicateOperatorType type = (NSPredicateOperatorType)[[values objectAtIndex:1] intValue];
        if ((int)type == 99)
        {
            predicate = [[TRLegacyContainsPredicate alloc] initWithKeyPath:[left keyPath]
                value:[right constantValue] modifier:[row->rowTemplate modifier] options:[row->rowTemplate options]];
        }
        else
        {
            predicate = [NSComparisonPredicate predicateWithLeftExpression:left rightExpression:right
                modifier:[row->rowTemplate modifier] type:type options:[row->rowTemplate options]];
        }
    }
    if (predicate != nil)
    {
        [row->rowTemplate setPredicate:predicate];
        [self tr_rowsChangedSendingAction:YES];
    }
}

- (void)reloadCriteria
{
    NSPredicate* value = [self objectValue];
    _predicate = nil;
    self.objectValue = value;
}

- (void)reloadPredicate
{
    _predicate = [self objectValue];
}

- (NSPopUpButton*)tr_popUpWithTemplatePopUp:(NSPopUpButton*)source frame:(NSRect)frame tag:(NSInteger)tag
{
    NSPopUpButton* popUp = [[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
    TRCenteredPopUpButtonCell* cell = [[TRCenteredPopUpButtonCell alloc] initTextCell:@"" pullsDown:NO];
    [popUp setCell:cell];
    [[popUp cell] setControlSize:NSSmallControlSize];
    [[popUp cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    if (source != nil)
    {
        [popUp setMenu:[[source menu] copy]];
    }
    [popUp setTag:tag];
    [popUp setTarget:self];
    [popUp setAction:@selector(tr_controlChanged:)];
    return popUp;
}

- (NSPopUpButton*)tr_popUpWithCriterionNodes:(NSArray*)nodes frame:(NSRect)frame tag:(NSInteger)tag
{
    NSPopUpButton* popUp = [self tr_popUpWithTemplatePopUp:nil frame:frame tag:tag];
    NSEnumerator* enumerator = [nodes objectEnumerator];
    TRPredicateEditorCriterionNode* node = nil;
    while ((node = [enumerator nextObject]) != nil)
    {
        if ([node->title isEqualToString:@"\n---"])
        {
            [[popUp menu] addItem:[NSMenuItem separatorItem]];
        }
        else
        {
            [popUp addItemWithTitle:node->title ?: @""];
            [[popUp lastItem] setRepresentedObject:node->representedObject];
        }
    }
    return popUp;
}

- (void)tr_selectPopUp:(NSPopUpButton*)popUp representedObject:(id)object
{
    NSInteger index = [popUp indexOfItemWithRepresentedObject:object];
    if (index >= 0)
    {
        [popUp selectItemAtIndex:index];
    }
}

- (void)tr_rebuildViews
{
    NSArray* oldSubviews = [[self subviews] copy];
    NSEnumerator* oldEnumerator = [oldSubviews objectEnumerator];
    NSView* oldView = nil;
    while ((oldView = [oldEnumerator nextObject]) != nil)
    {
        [oldView removeFromSuperview];
    }

    NSMutableArray* rows = [NSMutableArray array];
    NSMutableArray* depths = [NSMutableArray array];
    TRAppendRows(_rootRows, rows, depths, 0);
    NSArray* simpleCriterionTree = TRMergedCriterionTree(_rowTemplates, NO);
    CGFloat width = NSWidth([self bounds]);
    for (NSUInteger index = 0; index < [rows count]; ++index)
    {
        TRPredicateEditorRow* row = [rows objectAtIndex:index];
        NSUInteger depth = (NSUInteger)[[depths objectAtIndex:index] intValue];
        CGFloat y = index * _ruleEditorRowHeight;
        CGFloat x = 7.0 + depth * 30.0;
        CGFloat buttonsWidth = 43.0;
        CGFloat available = MAX(120.0, width - x - buttonsWidth - 8.0);
        NSArray* templateViews = [row->rowTemplate templateViews];
        NSPredicate* predicate = [self tr_predicateFromRow:row];

        if ([[row->rowTemplate compoundTypes] count] != 0)
        {
            NSPopUpButton* typePopUp = [self tr_popUpWithTemplatePopUp:TRPopUpAtIndex(templateViews, 0)
                frame:NSMakeRect(x, y + 3.0, MIN(80.0, available * 0.3), 19.0) tag:(NSInteger)index * 10 + 1];
            NSArray* ignored = nil;
            [self tr_selectPopUp:typePopUp representedObject:[NSNumber numberWithInt:(int)
                TRNormalizedCompoundType((NSCompoundPredicate*)predicate, &ignored)]];
            [self addSubview:typePopUp];
            CGFloat labelX = NSMaxX([typePopUp frame]) + 6.0;
            NSTextField* label = [[NSTextField alloc] initWithFrame:NSMakeRect(labelX, y + 4.0, available - (labelX - x), 17.0)];
            [label setBordered:NO];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [label setSelectable:NO];
            [label setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
            NSPopUpButton* descriptionPopUp = TRPopUpAtIndex(templateViews, 1);
            NSString* description = [[descriptionPopUp selectedItem] title];
            [label setStringValue:description ?: @"of the following are true"];
            [self addSubview:label];
        }
        else
        {
            CGFloat leftWidth = MIN(110.0, available * 0.31);
            CGFloat operatorWidth = MIN(105.0, available * 0.3);
            CGFloat valueWidth = MAX(55.0, available - leftWidth - operatorWidth - 12.0);
            NSPopUpButton* left = [self tr_popUpWithCriterionNodes:simpleCriterionTree
                frame:NSMakeRect(x, y + 3.0, leftWidth, 19.0) tag:(NSInteger)index * 10 + 2];
            [self tr_selectPopUp:left representedObject:TRLeftExpressionForPredicate(predicate)];
            [self addSubview:left];
            NSPopUpButton* op = [self tr_popUpWithTemplatePopUp:TRPopUpAtIndex(templateViews, 1)
                frame:NSMakeRect(NSMaxX([left frame]) + 4.0, y + 3.0, operatorWidth, 19.0) tag:(NSInteger)index * 10 + 3];
            [self tr_selectPopUp:op representedObject:[NSNumber numberWithInt:(int)TROperatorForPredicate(predicate)]];
            [self addSubview:op];
            NSTextField* value = [[NSTextField alloc] initWithFrame:NSMakeRect(NSMaxX([op frame]) + 4.0, y + 4.0, valueWidth, 18.0)];
            [value setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
            [value setStringValue:[TRRightExpressionForPredicate(predicate) constantValue] ?: @""];
            [value setTag:(NSInteger)index * 10 + 4];
            [value setDelegate:self];
            [value setTarget:self];
            [value setAction:@selector(tr_controlChanged:)];
            [self addSubview:value];
        }

        if ([self tr_canRemoveRow:row])
        {
            NSButton* minus = [[TRPredicateEditorButton alloc] initWithFrame:NSMakeRect(width - 42.0, y + 4.0, 18.0, 18.0)];
            [minus setTitle:@"-"];
            [minus setBordered:NO];
            [minus setTag:(NSInteger)index * 10 + 5];
            [minus setTarget:self];
            [minus setAction:@selector(removeRow:)];
            [self addSubview:minus];
        }

        NSButton* plus = [[TRPredicateEditorButton alloc] initWithFrame:NSMakeRect(width - 22.0, y + 4.0, 18.0, 18.0)];
        [plus setTitle:@"+"];
        [plus setBordered:NO];
        [plus setTag:(NSInteger)index * 10 + 6];
        [plus setTarget:self];
        [plus setAction:@selector(tr_addFromButton:)];
        [self addSubview:plus];
    }
    CGFloat height = MAX(NSHeight([[self superview] bounds]), [rows count] * _ruleEditorRowHeight);
    [super setFrameSize:NSMakeSize(NSWidth([self frame]), height)];
    [self setNeedsDisplay:YES];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    if (_didFinishNibLoading)
    {
        [self tr_rebuildViews];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor controlBackgroundColor] set];
    NSRectFill(dirtyRect);
    NSInteger rows = [self numberOfRows];
    for (NSInteger row = 0; row < rows; ++row)
    {
        NSRect rowRect = NSMakeRect(0.0, row * _ruleEditorRowHeight, NSWidth([self bounds]), _ruleEditorRowHeight);
        if ([_selectedRowIndexes containsIndex:(NSUInteger)row])
        {
            [[NSColor selectedControlColor] set];
            NSRectFillUsingOperation(rowRect, NSCompositeSourceOver);
        }
        [[NSColor gridColor] set];
        NSRectFill(NSMakeRect(0.0, NSMaxY(rowRect) - 1.0, NSWidth(rowRect), 1.0));
    }
}

- (void)tr_addFromButton:(id)sender
{
    NSEvent* event = [NSApp currentEvent];
    if (([event modifierFlags] & NSAlternateKeyMask) != 0)
    {
        [self addGroup:sender];
    }
    else
    {
        [self tr_addSimpleRowFromSender:sender];
    }
}

- (void)tr_controlChanged:(id)sender
{
    NSInteger encodedTag = [sender tag];
    NSInteger rowIndex = encodedTag / 10;
    NSInteger role = encodedTag % 10;
    TRPredicateEditorRow* row = [self tr_rowAtIndex:rowIndex];
    if (row == nil)
    {
        return;
    }
    [_selectedRowIndexes removeAllIndexes];
    [_selectedRowIndexes addIndex:(NSUInteger)rowIndex];
    NSPredicate* oldPredicate = [self tr_predicateFromRow:row];
    NSPredicate* changed = nil;
    if (role == 1)
    {
        NSCompoundPredicateType type = (NSCompoundPredicateType)[[[sender selectedItem] representedObject] intValue];
        NSArray* subpredicates = [(NSCompoundPredicate*)oldPredicate subpredicates];
        if (type == NSOrPredicateType)
            changed = [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
        else if (type == NSNotPredicateType)
            changed = [NSCompoundPredicate notPredicateWithSubpredicate:[NSCompoundPredicate orPredicateWithSubpredicates:subpredicates]];
        else
            changed = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    }
    else
    {
        NSExpression* left = TRLeftExpressionForPredicate(oldPredicate);
        NSPredicateOperatorType type = TROperatorForPredicate(oldPredicate);
        NSExpression* right = TRRightExpressionForPredicate(oldPredicate);
        if (role == 2)
        {
            left = [[sender selectedItem] representedObject];
            TRPredicateEditorCriterionNode* criterion = TRCriterionNodeForRepresentedObject(
                TRMergedCriterionTree(_rowTemplates, NO), left);
            NSPredicateEditorRowTemplate* sourceTemplate = criterion != nil ? criterion->rowTemplate : nil;
            if (sourceTemplate != nil && ![[row->rowTemplate leftExpressions] containsObject:left])
            {
                row->rowTemplate = [sourceTemplate copy];
                if (![[row->rowTemplate operators] containsObject:[NSNumber numberWithInt:(int)type]])
                {
                    type = (NSPredicateOperatorType)[[[row->rowTemplate operators] objectAtIndex:0] intValue];
                }
            }
        }
        else if (role == 3)
        {
            type = (NSPredicateOperatorType)[[[sender selectedItem] representedObject] intValue];
        }
        else if (role == 4)
        {
            right = [NSExpression expressionForConstantValue:[sender stringValue]];
        }
        if ((int)type == 99)
        {
            changed = [[TRLegacyContainsPredicate alloc] initWithKeyPath:[left keyPath]
                value:[right constantValue] modifier:[row->rowTemplate modifier] options:[row->rowTemplate options]];
        }
        else
        {
            changed = [NSComparisonPredicate predicateWithLeftExpression:left rightExpression:right
                modifier:[row->rowTemplate modifier] type:type options:[row->rowTemplate options]];
        }
    }
    [row->rowTemplate setPredicate:changed];
    if (role == 4)
    {
        _predicate = [self tr_currentPredicate];
        [self tr_sendAction];
        [self setNeedsDisplay:YES];
    }
    else
    {
        [self tr_rowsChangedSendingAction:YES];
    }
}

- (void)controlTextDidChange:(NSNotification*)notification
{
    [self tr_controlChanged:[notification object]];
}

- (void)tr_rowsChangedSendingAction:(BOOL)sendAction
{
    _predicate = [self tr_currentPredicate];
    [self tr_rebuildViews];
    NSNotification* notification = [NSNotification notificationWithName:TRRowsDidChangeNotification object:self];
    if ([_ruleEditorDelegate respondsToSelector:@selector(ruleEditorRowsDidChange:)])
    {
        [_ruleEditorDelegate ruleEditorRowsDidChange:notification];
    }
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    if (sendAction)
    {
        [self tr_sendAction];
    }
}

- (void)tr_sendAction
{
    if ([self action] == NULL)
    {
        return;
    }
    if ([self target] != nil)
    {
        NSMethodSignature* signature = [[self target] methodSignatureForSelector:[self action]];
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
        id sender = self;
        [invocation setTarget:[self target]];
        [invocation setSelector:[self action]];
        [invocation setArgument:&sender atIndex:2];
        [invocation invoke];
    }
    else
    {
        [NSApp sendAction:[self action] to:nil from:self];
    }
}

@end

#endif
