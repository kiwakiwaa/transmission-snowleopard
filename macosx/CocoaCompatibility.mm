// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "CocoaCompatibility.h"
#import "LegacyAssociatedObjects.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
static NSImage* TRTigerPlusMinusImage(BOOL plus)
{
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(14.0, 14.0)];
    [image lockFocus];
    [[NSColor controlTextColor] set];
    NSRectFill(NSMakeRect(3.0, 6.0, 8.0, 2.0));
    if (plus)
    {
        NSRectFill(NSMakeRect(6.0, 3.0, 2.0, 8.0));
    }
    [image unlockFocus];
    return image;
}

static void TRRegisterTigerNamedImage(NSImage* image, NSString* name, NSMutableArray* registry)
{
    if (image != nil && [image setName:name])
    {
        [registry addObject:image];
    }
}

void TRInstallTigerNamedImageFallbacks(void)
{
    static BOOL installed = NO;
    static NSMutableArray* registry = nil;
    if (installed)
    {
        return;
    }
    installed = YES;
    registry = [[NSMutableArray alloc] initWithCapacity:4];

    NSImage* action = [[NSImage imageNamed:@"ActionGear"] copy];
    if (action == nil)
    {
        action = [[NSImage imageNamed:NSImageNamePreferencesGeneral] copy];
    }
    if (action == nil)
    {
        action = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [action lockFocus];
        [[NSColor controlTextColor] set];
        NSBezierPath* outer = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(2.5, 2.5, 11.0, 11.0)];
        outer.lineWidth = 2.0;
        [outer stroke];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(6.0, 6.0, 4.0, 4.0)] fill];
        [action unlockFocus];
    }
    TRRegisterTigerNamedImage(action, @"NSActionTemplate", registry);

    TRRegisterTigerNamedImage(TRTigerPlusMinusImage(YES), @"NSAddTemplate", registry);
    TRRegisterTigerNamedImage(TRTigerPlusMinusImage(NO), @"NSRemoveTemplate", registry);

    NSImage* yellowDot = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
    [yellowDot lockFocus];
    [[NSColor colorWithCalibratedRed:0.95 green:0.72 blue:0.12 alpha:1.0] set];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(3.0, 3.0, 10.0, 10.0)] fill];
    [yellowDot unlockFocus];
    TRRegisterTigerNamedImage(yellowDot, @"YellowDot", registry);
}

@implementation NSCache
- (id)init
{
    if ((self = [super init]))
    {
        _objects = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (id)objectForKey:(id)key
{
    return [_objects objectForKey:key];
}
- (void)setObject:(id)object forKey:(id)key
{
    [_objects setObject:object forKey:key];
}
@end
#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_12

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
@interface TRLegacyTimerBlockTarget : NSObject
{
    TRTimerBlock _block;
}
@property(nonatomic, copy) TRTimerBlock block;
- (instancetype)initWithBlock:(TRTimerBlock)block;
- (void)fireTimer:(NSTimer*)timer;
@end

@implementation TRLegacyTimerBlockTarget

@synthesize block = _block;

- (instancetype)initWithBlock:(TRTimerBlock)block
{
    if ((self = [super init]))
    {
        self.block = block;
    }
    return self;
}

- (void)fireTimer:(NSTimer*)timer
{
    TRTimerBlock block = self.block;
    if (block != nil)
    {
        block(timer);
    }
}

@end
#endif

@implementation NSTimer (TRLegacyBlockTimer)

+ (void)tr_fireBlockTimer:(NSTimer*)timer
{
    TRTimerBlock block = (TRTimerBlock)timer.userInfo;
    if (block != nil)
    {
        block(timer);
    }
}

+ (NSTimer*)tr_scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(TRTimerBlock)block
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    TRLegacyTimerBlockTarget* target = [[TRLegacyTimerBlockTarget alloc] initWithBlock:block];
    return [self scheduledTimerWithTimeInterval:interval
                                         target:target
                                       selector:@selector(fireTimer:)
                                       userInfo:nil
                                        repeats:repeats];
#else
    return [self scheduledTimerWithTimeInterval:interval target:self selector:@selector(tr_fireBlockTimer:) userInfo:[block copy] repeats:repeats];
#endif
}

+ (NSTimer*)tr_timerWithFireDate:(NSDate*)date interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(TRTimerBlock)block
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    TRLegacyTimerBlockTarget* target = [[TRLegacyTimerBlockTarget alloc] initWithBlock:block];
    return [[self alloc] initWithFireDate:date
                                interval:interval
                                  target:target
                                selector:@selector(fireTimer:)
                                userInfo:nil
                                 repeats:repeats];
#else
    return [[self alloc] initWithFireDate:date interval:interval target:self selector:@selector(tr_fireBlockTimer:) userInfo:[block copy] repeats:repeats];
#endif
}

@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
// On Mac OS X 10.6 and later, NSObject provides an implementation of awakeFromNib.
// Tiger and Leopard do not, so [super awakeFromNib] in an override
// would otherwise raise an unrecognized selector exception
@implementation NSObject (TRLegacyNibAwakening)
- (void)awakeFromNib
{
}
@end

@implementation NSCell (TRLegacySingleLineModeDeclarations)

- (BOOL)usesSingleLineMode
{
    return NO;
}

- (void)setUsesSingleLineMode:(BOOL)usesSingleLineMode
{
    (void)usesSingleLineMode;
}

- (NSBackgroundStyle)backgroundStyle
{
    return [self isHighlighted] ? NSBackgroundStyleDark : NSBackgroundStyleLight;
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    (void)backgroundStyle;
}

@end

@implementation NSIndexSet (TRLegacyRangeCountingDeclarations)

- (NSUInteger)countOfIndexesInRange:(NSRange)range
{
    NSUInteger count = 0;
    NSUInteger const end = NSMaxRange(range);
    for (NSUInteger index = [self firstIndex]; index != NSNotFound && index < end; index = [self indexGreaterThanIndex:index])
    {
        if (index >= range.location)
        {
            ++count;
        }
    }
    return count;
}

- (void)enumerateIndexesUsingBlock:(void (^)(NSUInteger idx, BOOL* stop))block
{
    BOOL stop = NO;
    for (NSUInteger index = [self firstIndex]; index != NSNotFound && !stop; index = [self indexGreaterThanIndex:index])
    {
        block(index, &stop);
    }
}

@end

@implementation NSArray (TRLegacyBlockEnumerationDeclarations)

- (void)enumerateObjectsWithOptions:(NSUInteger)options usingBlock:(void (^)(id obj, NSUInteger idx, BOOL* stop))block
{
    (void)options;
    BOOL stop = NO;
    NSUInteger const count = self.count;
    for (NSUInteger index = 0; index < count && !stop; ++index)
    {
        block([self objectAtIndex:index], index, &stop);
    }
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet*)indexes
                           options:(NSUInteger)options
                        usingBlock:(void (^)(id obj, NSUInteger idx, BOOL* stop))block
{
    (void)options;
    BOOL stop = NO;
    for (NSUInteger index = [indexes firstIndex]; index != NSNotFound && !stop; index = [indexes indexGreaterThanIndex:index])
    {
        block([self objectAtIndex:index], index, &stop);
    }
}

- (NSUInteger)indexOfObjectWithOptions:(NSUInteger)options passingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL* stop))predicate
{
    (void)options;
    BOOL stop = NO;
    NSUInteger const count = self.count;
    for (NSUInteger index = 0; index < count && !stop; ++index)
    {
        if (predicate([self objectAtIndex:index], index, &stop))
        {
            return index;
        }
    }
    return NSNotFound;
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet*)indexes
                              options:(NSUInteger)options
                          passingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL* stop))predicate
{
    (void)options;
    BOOL stop = NO;
    for (NSUInteger index = [indexes firstIndex]; index != NSNotFound && !stop; index = [indexes indexGreaterThanIndex:index])
    {
        if (predicate([self objectAtIndex:index], index, &stop))
        {
            return index;
        }
    }
    return NSNotFound;
}

- (NSIndexSet*)indexesOfObjectsWithOptions:(NSUInteger)options passingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL* stop))predicate
{
    (void)options;
    NSMutableIndexSet* result = [NSMutableIndexSet indexSet];
    BOOL stop = NO;
    NSUInteger const count = self.count;
    for (NSUInteger index = 0; index < count && !stop; ++index)
    {
        if (predicate([self objectAtIndex:index], index, &stop))
        {
            [result addIndex:index];
        }
    }
    return result;
}

- (NSIndexSet*)indexesOfObjectsAtIndexes:(NSIndexSet*)indexes
                                  options:(NSUInteger)options
                              passingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL* stop))predicate
{
    (void)options;
    NSMutableIndexSet* result = [NSMutableIndexSet indexSet];
    BOOL stop = NO;
    for (NSUInteger index = [indexes firstIndex]; index != NSNotFound && !stop; index = [indexes indexGreaterThanIndex:index])
    {
        if (predicate([self objectAtIndex:index], index, &stop))
        {
            [result addIndex:index];
        }
    }
    return result;
}

@end

@implementation NSControl (TRLegacyIntegerValueDeclarations)

- (NSInteger)integerValue
{
    return [self intValue];
}

- (void)setIntegerValue:(NSInteger)value
{
    [self setIntValue:value];
}

@end

@implementation NSImage (TRLegacyDrawingDeclarations)

- (BOOL)isTemplate
{
    return NO;
}

- (void)setTemplate:(BOOL)isTemplate
{
    (void)isTemplate;
}

- (void)drawInRect:(NSRect)rect
          fromRect:(NSRect)fromRect
         operation:(NSCompositingOperation)operation
          fraction:(CGFloat)fraction
    respectFlipped:(BOOL)respectFlipped
             hints:(NSDictionary*)hints
{
    (void)respectFlipped;
    (void)hints;
    [self drawInRect:rect fromRect:fromRect operation:operation fraction:fraction];
}

@end

@implementation NSEvent (TRLegacyModifierFlagsDeclarations)

+ (NSUInteger)modifierFlags
{
    return [[NSApp currentEvent] modifierFlags];
}

@end

@implementation NSNumber (TRLegacyIntegerDeclarations)

+ (NSNumber*)numberWithInteger:(NSInteger)value
{
    return [self numberWithInt:value];
}

- (NSInteger)integerValue
{
    return [self intValue];
}

@end

@implementation NSString (TRLegacyReplacingDeclarations)

- (NSString*)stringByReplacingCharactersInRange:(NSRange)range withString:(NSString*)replacement
{
    NSMutableString* string = [self mutableCopy];
    [string replaceCharactersInRange:range withString:replacement];
    return string;
}

- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)target withString:(NSString*)replacement
{
    return [[self componentsSeparatedByString:target] componentsJoinedByString:replacement];
}

@end

@implementation NSBezierPath (TRLegacyRoundedRectDeclarations)

+ (NSBezierPath*)bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius
{
    CGFloat const radius = MIN(MIN(xRadius, yRadius), MIN(NSWidth(rect), NSHeight(rect)) * 0.5);
    NSBezierPath* path = [NSBezierPath bezierPath];

    if (radius <= 0.0)
    {
        [path appendBezierPathWithRect:rect];
        return path;
    }

    CGFloat const minX = NSMinX(rect);
    CGFloat const maxX = NSMaxX(rect);
    CGFloat const minY = NSMinY(rect);
    CGFloat const maxY = NSMaxY(rect);

    [path moveToPoint:NSMakePoint(minX + radius, minY)];
    [path lineToPoint:NSMakePoint(maxX - radius, minY)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(maxX - radius, minY + radius) radius:radius startAngle:270.0 endAngle:360.0];
    [path lineToPoint:NSMakePoint(maxX, maxY - radius)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(maxX - radius, maxY - radius) radius:radius startAngle:0.0 endAngle:90.0];
    [path lineToPoint:NSMakePoint(minX + radius, maxY)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(minX + radius, maxY - radius) radius:radius startAngle:90.0 endAngle:180.0];
    [path lineToPoint:NSMakePoint(minX, minY + radius)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(minX + radius, minY + radius) radius:radius startAngle:180.0 endAngle:270.0];
    [path closePath];

    return path;
}

@end

@implementation NSTableColumn (TRLegacyHeaderToolTipDeclarations)

- (NSString*)headerToolTip
{
    return nil;
}

- (void)setHeaderToolTip:(NSString*)headerToolTip
{
    (void)headerToolTip;
}

@end

@implementation NSTableView (TRLegacyReloadDeclarations)

- (NSCell*)preparedCellAtColumn:(NSInteger)column row:(NSInteger)row
{
    (void)row;
    NSTableColumn* tableColumn = [[self tableColumns] objectAtIndex:column];
    return [tableColumn dataCell];
}

- (void)reloadDataForRowIndexes:(NSIndexSet*)rowIndexes columnIndexes:(NSIndexSet*)columnIndexes
{
    (void)rowIndexes;
    (void)columnIndexes;
    [self reloadData];
}

@end
#endif

NSURL* TRURLForResource(NSBundle* bundle, NSString* name, NSString* extension)
{
    if (bundle == nil)
    {
        return nil;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    if ([bundle respondsToSelector:@selector(URLForResource:withExtension:)])
    {
        return [bundle URLForResource:name withExtension:extension];
    }

    NSString* path = [bundle pathForResource:name ofType:extension];
    return path != nil ? [NSURL fileURLWithPath:path] : nil;
#else
    return [bundle URLForResource:name withExtension:extension];
#endif
}

NSDate* TRDateByAddingTimeInterval(NSDate* date, NSTimeInterval interval)
{
    if (date == nil)
    {
        return nil;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [[NSDate alloc] initWithTimeInterval:interval sinceDate:date];
#else
    return [date dateByAddingTimeInterval:interval];
#endif
}

NSRunLoop* TRMainRunLoop(void)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [NSRunLoop currentRunLoop];
#else
    return [NSRunLoop mainRunLoop];
#endif
}

BOOL TRMoveItemAtPath(NSFileManager* fileManager, NSString* sourcePath, NSString* destinationPath, NSError** error)
{
    if (fileManager == nil)
    {
        fileManager = NSFileManager.defaultManager;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [fileManager movePath:sourcePath toPath:destinationPath handler:nil];
#else
    return [fileManager moveItemAtPath:sourcePath toPath:destinationPath error:error];
#endif
}

BOOL TRRemoveItemAtPath(NSFileManager* fileManager, NSString* path, NSError** error)
{
    if (fileManager == nil)
    {
        fileManager = NSFileManager.defaultManager;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [fileManager removeFileAtPath:path handler:nil];
#else
    return [fileManager removeItemAtPath:path error:error];
#endif
}

NSArray* TRContentsOfDirectoryAtPath(NSFileManager* fileManager, NSString* path, NSError** error)
{
    if (fileManager == nil)
    {
        fileManager = NSFileManager.defaultManager;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [fileManager directoryContentsAtPath:path];
#else
    return [fileManager contentsOfDirectoryAtPath:path error:error];
#endif
}

NSDictionary* TRAttributesOfItemAtPath(NSFileManager* fileManager, NSString* path, NSError** error)
{
    if (fileManager == nil)
    {
        fileManager = NSFileManager.defaultManager;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [fileManager fileAttributesAtPath:path traverseLink:NO];
#else
    return [fileManager attributesOfItemAtPath:path error:error];
#endif
}

BOOL TRCopyItemAtURL(NSFileManager* fileManager, NSURL* sourceURL, NSURL* destinationURL, NSError** error)
{
    if (fileManager == nil)
    {
        fileManager = NSFileManager.defaultManager;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [fileManager copyPath:sourceURL.path toPath:destinationURL.path handler:nil];
#else
    return [fileManager copyItemAtURL:sourceURL toURL:destinationURL error:error];
#endif
}

BOOL TRMoveItemAtURL(NSFileManager* fileManager, NSURL* sourceURL, NSURL* destinationURL, NSError** error)
{
    if (fileManager == nil)
    {
        fileManager = NSFileManager.defaultManager;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [fileManager movePath:sourceURL.path toPath:destinationURL.path handler:nil];
#else
    return [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:error];
#endif
}

NSString* TRWorkspaceTypeOfFile(NSWorkspace* workspace, NSString* path, NSError** error)
{
    if (workspace == nil)
    {
        workspace = NSWorkspace.sharedWorkspace;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    NSString* type = nil;
    return [workspace getInfoForFile:path application:nil type:&type] ? type : nil;
#else
    return [workspace typeOfFile:path error:error];
#endif
}

BOOL TRIsTorrentFileAtPath(NSString* path)
{
    if (path == nil)
    {
        return NO;
    }

    return [TRWorkspaceTypeOfFile(NSWorkspace.sharedWorkspace, path, NULL) isEqualToString:@"org.bittorrent.torrent"] ||
        [[path pathExtension] caseInsensitiveCompare:@"torrent"] == NSOrderedSame;
}

NSURL* TRURLByDeletingLastPathComponent(NSURL* URL)
{
    if (URL == nil)
    {
        return nil;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [NSURL fileURLWithPath:[URL.path stringByDeletingLastPathComponent]];
#else
    return URL.URLByDeletingLastPathComponent;
#endif
}

NSURL* TRURLByDeletingPathExtension(NSURL* URL)
{
    if (URL == nil)
    {
        return nil;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [NSURL fileURLWithPath:[URL.path stringByDeletingPathExtension]];
#else
    return URL.URLByDeletingPathExtension;
#endif
}

NSURL* TRURLByAppendingPathComponent(NSURL* URL, NSString* pathComponent)
{
    if (URL == nil || pathComponent == nil)
    {
        return nil;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [NSURL fileURLWithPath:[URL.path stringByAppendingPathComponent:pathComponent]];
#else
    return [URL URLByAppendingPathComponent:pathComponent];
#endif
}

NSString* TRURLLastPathComponent(NSURL* URL)
{
    return URL.path.lastPathComponent;
}

NSString* TRURLPathExtension(NSURL* URL)
{
    return URL.path.pathExtension;
}

NSArray* TRURLPathComponents(NSURL* URL)
{
    return URL.path.pathComponents;
}

BOOL TRURLCheckResourceIsReachable(NSURL* URL, NSError** error)
{
    if (URL == nil)
    {
        return NO;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)error;
    return [NSFileManager.defaultManager fileExistsAtPath:URL.path];
#else
    return [URL checkResourceIsReachableAndReturnError:error];
#endif
}

NSURL* TRUserDefaultsURLForKey(NSUserDefaults* defaults, NSString* key)
{
    if (defaults == nil)
    {
        defaults = NSUserDefaults.standardUserDefaults;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    NSString* path = [defaults stringForKey:key];
    return path.length > 0 ? [NSURL fileURLWithPath:path] : nil;
#else
    return [defaults URLForKey:key];
#endif
}

void TRUserDefaultsSetURL(NSUserDefaults* defaults, NSURL* URL, NSString* key)
{
    if (defaults == nil)
    {
        defaults = NSUserDefaults.standardUserDefaults;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    if (URL.path != nil)
    {
        [defaults setObject:URL.path forKey:key];
    }
#else
    [defaults setURL:URL forKey:key];
#endif
}

void TRCoderEncodeInteger(NSCoder* coder, NSInteger value, NSString* key)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    [coder encodeInt:value forKey:key];
#else
    [coder encodeInteger:value forKey:key];
#endif
}

NSInteger TRCoderDecodeInteger(NSCoder* coder, NSString* key)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [coder decodeIntForKey:key];
#else
    return [coder decodeIntegerForKey:key];
#endif
}

void TRPasteboardWriteStrings(NSPasteboard* pasteboard, NSArray* strings)
{
    if (pasteboard == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    NSString* string = [strings componentsJoinedByString:@"\n"];
    [pasteboard declareTypes:@[ NSStringPboardType ] owner:nil];
    [pasteboard setString:string forType:NSStringPboardType];
#else
    [pasteboard clearContents];
    [pasteboard writeObjects:strings];
#endif
}

NSArray* TRPasteboardReadStrings(NSPasteboard* pasteboard)
{
    if (pasteboard == nil)
    {
        return @[];
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    NSString* string = [pasteboard stringForType:NSStringPboardType];
    return string != nil ? @[ string ] : @[];
#else
    NSArray* strings = [pasteboard readObjectsForClasses:@[ [NSString class] ] options:nil];
    return strings != nil ? strings : @[];
#endif
}

BOOL TRPasteboardCanReadStrings(NSPasteboard* pasteboard)
{
    if (pasteboard == nil)
    {
        return NO;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [pasteboard availableTypeFromArray:@[ NSStringPboardType ]] != nil;
#else
    return [pasteboard canReadObjectForClasses:@[ [NSString class] ] options:nil];
#endif
}

NSArray* TRPasteboardReadURLs(NSPasteboard* pasteboard)
{
    if (pasteboard == nil)
    {
        return @[];
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    id const filenamesPropertyList = [pasteboard propertyListForType:NSFilenamesPboardType];
    if ([filenamesPropertyList isKindOfClass:[NSArray class]])
    {
        NSArray* const filenames = filenamesPropertyList;
        NSMutableArray* const URLs = [NSMutableArray arrayWithCapacity:[filenames count]];
        NSUInteger const count = [filenames count];
        for (NSUInteger index = 0; index < count; ++index)
        {
            id const filename = [filenames objectAtIndex:index];
            if ([filename isKindOfClass:[NSString class]])
            {
                [URLs addObject:[NSURL fileURLWithPath:filename]];
            }
        }

        if ([URLs count] != 0)
        {
            return URLs;
        }
    }

    NSURL* URL = [NSURL URLFromPasteboard:pasteboard];
    return URL != nil ? @[ URL ] : @[];
#else
    NSArray* URLs = [pasteboard readObjectsForClasses:@[ [NSURL class] ] options:nil];
    return URLs != nil ? URLs : @[];
#endif
}

void TRSavePanelSetDirectoryURL(NSSavePanel* panel, NSURL* directoryURL)
{
    if (panel == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    [panel setDirectory:directoryURL.path];
#else
    panel.directoryURL = directoryURL;
#endif
}

void TRSavePanelSetNameFieldStringValue(NSSavePanel* panel, NSString* name)
{
    if (panel == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)name;
#else
    panel.nameFieldStringValue = name;
#endif
}

void TRActivateFileViewerSelectingURLs(NSArray* URLs)
{
    if (URLs.count == 0)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    NSURL* URL = [URLs objectAtIndex:0];
    NSString* path = [URL path];
    if (path != nil)
    {
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
    }
#else
    [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:URLs];
#endif
}

NSSortDescriptor* TRSortDescriptor(NSString* key, BOOL ascending)
{
    return [[NSSortDescriptor alloc] initWithKey:key ascending:ascending];
}

NSSortDescriptor* TRSortDescriptorWithSelector(NSString* key, BOOL ascending, SEL selector)
{
    return [[NSSortDescriptor alloc] initWithKey:key ascending:ascending selector:selector];
}

void TRMenuRemoveAllItems(NSMenu* menu)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    while (menu.numberOfItems > 0)
    {
        [menu removeItemAtIndex:0];
    }
#else
    [menu removeAllItems];
#endif
}

NSCharacterSet* TRNewlineCharacterSet(void)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    return [NSCharacterSet characterSetWithCharactersInString:@"\r\n"];
#else
    return NSCharacterSet.newlineCharacterSet;
#endif
}

NSString* TRFirstLineFromString(NSString* string)
{
    if (string == nil)
    {
        return @"";
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    NSRange newlineRange = [string rangeOfCharacterFromSet:TRNewlineCharacterSet()];
    return newlineRange.location == NSNotFound ? string : [string substringToIndex:newlineRange.location];
#else
    return [[string componentsSeparatedByCharactersInSet:TRNewlineCharacterSet()] objectAtIndex:0];
#endif
}

void TRSetWindowCollectionBehavior(NSWindow* window, NSWindowCollectionBehavior behavior)
{
    if (window == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    if (![window respondsToSelector:@selector(setCollectionBehavior:)])
    {
        return;
    }
#endif

    window.collectionBehavior = behavior;
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
static char TRLegacyAlertSuppressionButtonKey;
static char TRLegacyAlertShowsSuppressionButtonKey;

static NSButton* TRLegacyAlertSuppressionButton(NSAlert* alert)
{
    NSButton* button = TRLegacyGetAssociatedObject(alert, &TRLegacyAlertSuppressionButtonKey);
    if (button == nil)
    {
        button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 260, 18)];
        button.buttonType = NSSwitchButton;
        button.title = NSLocalizedString(@"Do not show this message again", "Alert suppression checkbox");
        button.state = NSOffState;
        [button sizeToFit];
        TRLegacySetAssociatedObject(alert, &TRLegacyAlertSuppressionButtonKey, button, TRLegacyAssociationRetainNonatomic);
    }

    return button;
}
#endif

void TRSetAlertShowsSuppressionButton(NSAlert* alert, BOOL showsSuppressionButton)
{
    if (alert == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    if ([alert respondsToSelector:@selector(setShowsSuppressionButton:)])
    {
        alert.showsSuppressionButton = showsSuppressionButton;
        return;
    }

    TRLegacySetAssociatedObject(
        alert, &TRLegacyAlertShowsSuppressionButtonKey, [NSNumber numberWithBool:showsSuppressionButton], TRLegacyAssociationRetainNonatomic);

    NSButton* button = TRLegacyAlertSuppressionButton(alert);
    if ([alert respondsToSelector:@selector(setAccessoryView:)])
    {
        [alert performSelector:@selector(setAccessoryView:) withObject:showsSuppressionButton ? button : nil];
    }
#else
    alert.showsSuppressionButton = showsSuppressionButton;
#endif
}

NSButton* TRAlertSuppressionButton(NSAlert* alert)
{
    if (alert == nil)
    {
        return nil;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    if ([alert respondsToSelector:@selector(suppressionButton)])
    {
        return alert.suppressionButton;
    }

    return TRLegacyAlertSuppressionButton(alert);
#else
    return alert.suppressionButton;
#endif
}

void TRSetCellUsesSingleLineMode(NSCell* cell, BOOL usesSingleLineMode)
{
    if (cell == nil)
    {
        return;
    }

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    if (![cell respondsToSelector:@selector(setUsesSingleLineMode:)])
    {
        return;
    }
#endif

    cell.usesSingleLineMode = usesSingleLineMode;
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_7

static char TRLegacyTableUpdateDepthKey;
static char TRLegacyTableNeedsReloadKey;

static NSInteger TRLegacyTableUpdateDepth(NSTableView* tableView)
{
    return [TRLegacyGetAssociatedObject(tableView, &TRLegacyTableUpdateDepthKey) intValue];
}

static void TRLegacySetTableUpdateDepth(NSTableView* tableView, NSInteger depth)
{
    TRLegacySetAssociatedObject(
        tableView, &TRLegacyTableUpdateDepthKey, [NSNumber numberWithInt:MAX(0, depth)], TRLegacyAssociationRetainNonatomic);
}

static BOOL TRLegacyTableNeedsReload(NSTableView* tableView)
{
    return [TRLegacyGetAssociatedObject(tableView, &TRLegacyTableNeedsReloadKey) boolValue];
}

static void TRLegacySetTableNeedsReload(NSTableView* tableView, BOOL needsReload)
{
    TRLegacySetAssociatedObject(
        tableView, &TRLegacyTableNeedsReloadKey, [NSNumber numberWithBool:needsReload], TRLegacyAssociationRetainNonatomic);
}

static void TRLegacyBeginTableUpdates(NSTableView* tableView)
{
    TRLegacySetTableUpdateDepth(tableView, TRLegacyTableUpdateDepth(tableView) + 1);
}

static void TRLegacyEndTableUpdates(NSTableView* tableView)
{
    NSInteger const depth = TRLegacyTableUpdateDepth(tableView) - 1;
    TRLegacySetTableUpdateDepth(tableView, depth);

    if (depth <= 0 && TRLegacyTableNeedsReload(tableView))
    {
        TRLegacySetTableNeedsReload(tableView, NO);
        [tableView reloadData];
    }
}

static void TRLegacyReloadTableWhenReady(NSTableView* tableView)
{
    if (TRLegacyTableUpdateDepth(tableView) > 0)
    {
        TRLegacySetTableNeedsReload(tableView, YES);
    }
    else
    {
        [tableView reloadData];
    }
}

@implementation NSLayoutConstraint

@synthesize constant;
@synthesize active;
@synthesize firstItem;
@synthesize secondItem;
@synthesize firstAttribute;
@synthesize animations;

+ (instancetype)constraintWithItem:(id)view1
                         attribute:(NSLayoutAttribute)attr1
                         relatedBy:(NSLayoutRelation)relation
                            toItem:(id)view2
                         attribute:(NSLayoutAttribute)attr2
                        multiplier:(CGFloat)multiplier
                          constant:(CGFloat)c
{
    NSLayoutConstraint* constraint = [[self alloc] init];
    constraint.firstItem = view1;
    constraint.secondItem = view2;
    constraint.firstAttribute = attr1;
    constraint.constant = c;
    return constraint;
}

+ (NSArray*)constraintsWithVisualFormat:(NSString*)format options:(NSLayoutFormatOptions)opts metrics:(NSDictionary*)metrics views:(NSDictionary*)views
{
    return @[];
}

+ (void)activateConstraints:(NSArray*)constraints
{
}

+ (void)deactivateConstraints:(NSArray*)constraints
{
}

- (id)animator
{
    return self;
}

@end

@implementation NSView (TRLegacyAutoLayout)

- (BOOL)translatesAutoresizingMaskIntoConstraints
{
    return YES;
}

- (void)setTranslatesAutoresizingMaskIntoConstraints:(BOOL)translatesAutoresizingMaskIntoConstraints
{
}

- (NSString*)identifier
{
    return nil;
}

- (void)setIdentifier:(NSString*)identifier
{
}

- (NSSize)fittingSize
{
    return self.frame.size;
}

- (NSArray*)constraints
{
    return @[];
}

- (void)addConstraint:(NSLayoutConstraint*)constraint
{
}

- (void)addConstraints:(NSArray*)constraints
{
}

- (void)removeConstraint:(NSLayoutConstraint*)constraint
{
}

- (void)removeConstraints:(NSArray*)constraints
{
}

- (void)layout
{
}

@end

@implementation NSTableCellView

@synthesize textField;
@synthesize imageView;
@synthesize objectValue;
@synthesize backgroundStyle;

@end

@implementation NSTableView (TRLegacyTableView)

- (BOOL)floatsGroupRows
{
    return NO;
}

- (void)setFloatsGroupRows:(BOOL)floatsGroupRows
{
}

- (void)beginUpdates
{
    TRLegacyBeginTableUpdates(self);
}

- (void)endUpdates
{
    TRLegacyEndTableUpdates(self);
}

- (void)moveRowAtIndex:(NSInteger)oldIndex toIndex:(NSInteger)newIndex
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)insertRowsAtIndexes:(NSIndexSet*)indexes withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)removeRowsAtIndexes:(NSIndexSet*)indexes withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (id)makeViewWithIdentifier:(NSString*)identifier owner:(id)owner
{
    return nil;
}

- (NSView*)viewAtColumn:(NSInteger)column row:(NSInteger)row makeIfNecessary:(BOOL)makeIfNecessary
{
    return nil;
}

- (NSInteger)rowForView:(NSView*)view
{
    if (view == nil)
    {
        return -1;
    }

    return [self rowAtPoint:[view convertPoint:NSZeroPoint toView:self]];
}

@end

@implementation NSOutlineView (TRLegacyTableAnimations)

- (void)beginUpdates
{
    TRLegacyBeginTableUpdates(self);
}

- (void)endUpdates
{
    TRLegacyEndTableUpdates(self);
}

- (void)insertItemsAtIndexes:(NSIndexSet*)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)removeItemsAtIndexes:(NSIndexSet*)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions
{
    TRLegacyReloadTableWhenReady(self);
}

- (void)moveItemAtIndex:(NSInteger)fromIndex inParent:(id)oldParent toIndex:(NSInteger)toIndex inParent:(id)newParent
{
    TRLegacyReloadTableWhenReady(self);
}

@end

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_5

@implementation NSAnimationContext (TRLegacyAnimationContext)

- (BOOL)allowsImplicitAnimation
{
    return NO;
}

- (void)setAllowsImplicitAnimation:(BOOL)allowsImplicitAnimation
{
}

- (void (^)(void))completionHandler
{
    return nil;
}

- (void)setCompletionHandler:(void (^)(void))completionHandler
{
}

+ (void)runAnimationGroup:(void (^)(NSAnimationContext* context))changes completionHandler:(void (^)(void))completionHandler
{
    if (changes != nil)
    {
        changes([NSAnimationContext currentContext]);
    }

    if (completionHandler != nil)
    {
        completionHandler();
    }
}

@end

#endif

@implementation NSWindow (TRLegacyRestoration)

- (BOOL)restorable
{
    return NO;
}

- (void)setRestorable:(BOOL)restorable
{
}

- (Class)restorationClass
{
    return Nil;
}

- (void)setRestorationClass:(Class)restorationClass
{
}

- (NSRect)convertRectToScreen:(NSRect)rect
{
    rect.origin = [self convertBaseToScreen:rect.origin];
    return rect;
}

@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8

@implementation NSFileManager (TRLegacyTrash)

- (BOOL)trashItemAtURL:(NSURL*)url resultingItemURL:(NSURL**)outResultingURL error:(NSError**)error
{
    if (outResultingURL != NULL)
    {
        *outResultingURL = nil;
    }

    if (![url isFileURL])
    {
        return NO;
    }

    NSString* path = url.path;
    NSInteger tag = 0;
    return [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                        source:path.stringByDeletingLastPathComponent
                                                   destination:@""
                                                         files:@[path.lastPathComponent]
                                                           tag:&tag];
}

@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8 && !TR_MACOS_DEPLOYMENT_BEFORE_10_7

@implementation NSAnimationContext (TRLegacyImplicitAnimation)

- (BOOL)allowsImplicitAnimation
{
    return NO;
}

- (void)setAllowsImplicitAnimation:(BOOL)allowsImplicitAnimation
{
}

@end

#endif

#if TR_MACOS_SDK_BEFORE_10_8

@implementation NSImage (TRLegacyImageDrawing)

+ (NSImage*)imageWithSize:(NSSize)size flipped:(BOOL)drawingHandlerShouldBeCalledWithFlippedContext drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler
{
    NSImage* image = [[self alloc] initWithSize:size];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    (void)drawingHandlerShouldBeCalledWithFlippedContext;
    [image lockFocus];
#else
    [image lockFocusFlipped:drawingHandlerShouldBeCalledWithFlippedContext];
#endif
    if (drawingHandler != nil)
    {
        drawingHandler(NSMakeRect(0, 0, size.width, size.height));
    }
    [image unlockFocus];
    return image;
}

@end

@implementation NSBundle (TRLegacyNibLoading)

- (BOOL)loadNibNamed:(NSString*)nibName owner:(id)owner topLevelObjects:(NSArray**)topLevelObjects
{
    if (topLevelObjects != NULL)
    {
        *topLevelObjects = nil;
    }

    return [NSBundle loadNibNamed:nibName owner:owner];
}

@end

@implementation NSSharingService

@synthesize title;
@synthesize image;
@synthesize delegate;

+ (NSArray*)sharingServicesForItems:(NSArray*)items
{
    return @[];
}

- (void)performWithItems:(NSArray*)items
{
}

@end

@implementation NSSharingServicePicker

@synthesize delegate;

- (instancetype)initWithItems:(NSArray*)items
{
    return [super init];
}

- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView*)positioningView preferredEdge:(NSRectEdge)preferredEdge
{
}

@end

@implementation NSSharingContentScope
@end

#endif
