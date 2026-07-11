// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyRegularExpression.h"

#if TR_MACOS_SDK_BEFORE_10_7

#import <objc/runtime.h>

#include <algorithm>
#include <climits>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>

namespace
{
using UBool = int8_t;
using UChar = uint16_t;
using UErrorCode = int32_t;

constexpr UErrorCode U_ZERO_ERROR = 0;
constexpr UErrorCode U_REGEX_STOPPED_BY_CALLER = 66305;
constexpr NSUInteger NSTextCheckingTypeRegularExpressionLegacy = 1ULL << 10;
NSString* const TRNSInvalidValueErrorKey = @"NSInvalidValue";

constexpr uint32_t UREGEX_CASE_INSENSITIVE = 2;
constexpr uint32_t UREGEX_COMMENTS = 4;
constexpr uint32_t UREGEX_DOTALL = 32;
constexpr uint32_t UREGEX_MULTILINE = 8;
constexpr uint32_t UREGEX_UNIX_LINES = 1;
constexpr uint32_t UREGEX_UWORD = 256;

constexpr NSMatchingOptions TRMatchingSkipResultObjects = 1U << 13;

#if !TR_MACOS_OBJC_FRAGILE_RUNTIME
struct URegularExpression;
#endif

extern "C" URegularExpression* uregex_open(UChar const* pattern, int32_t patternLength, uint32_t flags, void* parseError, UErrorCode* status);
extern "C" URegularExpression* uregex_clone(URegularExpression const* regex, UErrorCode* status);
extern "C" void uregex_close(URegularExpression* regex);
extern "C" int32_t uregex_groupCount(URegularExpression* regex, UErrorCode* status);
extern "C" void uregex_setText(URegularExpression* regex, UChar const* text, int32_t textLength, UErrorCode* status);
extern "C" void uregex_setRegion(URegularExpression* regex, int32_t regionStart, int32_t regionLimit, UErrorCode* status);
extern "C" UBool uregex_findNext(URegularExpression* regex, UErrorCode* status);
extern "C" int32_t uregex_start(URegularExpression* regex, int32_t groupNum, UErrorCode* status);
extern "C" int32_t uregex_end(URegularExpression* regex, int32_t groupNum, UErrorCode* status);
extern "C" UBool uregex_hitEnd(URegularExpression* regex, UErrorCode* status);
extern "C" UBool uregex_requireEnd(URegularExpression* regex, UErrorCode* status);
extern "C" void uregex_useAnchoringBounds(URegularExpression* regex, UBool b, UErrorCode* status);
extern "C" void uregex_useTransparentBounds(URegularExpression* regex, UBool b, UErrorCode* status);
extern "C" void uregex_setMatchCallback(URegularExpression* regex, UBool (*callback)(void const*, int32_t), void const* context, UErrorCode* status);

#if __has_feature(objc_arc)
#define TR_AUTORELEASE(obj) (obj)
#else
#define TR_AUTORELEASE(obj) [(obj) autorelease]
#endif

[[nodiscard]] BOOL TRRangeIsValid(NSString* string, NSRange range)
{
    NSUInteger const length = [string length];
    return range.location <= length && range.length <= length - range.location;
}

void TRRaiseNilArgument(id self, SEL selector)
{
    (void)self;
    [NSException raise:NSInvalidArgumentException format:@"%@: nil argument", NSStringFromSelector(selector)];
}

void TRRaiseRangeException(id self, SEL selector)
{
    (void)self;
    [NSException raise:NSRangeException format:@"%@: Range or index out of bounds", NSStringFromSelector(selector)];
}

[[nodiscard]] NSString* TREscapeString(NSString* string, NSString* chars)
{
    if (string == nil)
    {
        return nil;
    }

    NSCharacterSet* characterSet = [NSCharacterSet characterSetWithCharactersInString:chars];
    NSRange foundRange = [string rangeOfCharacterFromSet:characterSet];
    if (foundRange.length == 0)
    {
        return string;
    }

    NSMutableString* escaped = [NSMutableString stringWithString:string];
    while (foundRange.length != 0)
    {
        [escaped insertString:@"\\" atIndex:foundRange.location];
        NSUInteger const nextLocation = NSMaxRange(foundRange) + 1;
        if (nextLocation >= [escaped length])
        {
            break;
        }

        foundRange = [escaped rangeOfCharacterFromSet:characterSet
                                              options:0
                                                range:NSMakeRange(nextLocation, [escaped length] - nextLocation)];
    }

    return escaped;
}

[[nodiscard]] uint32_t TRICUFlags(NSRegularExpressionOptions options)
{
    uint32_t flags = 0;
    if ((options & NSRegularExpressionCaseInsensitive) != 0)
    {
        flags |= UREGEX_CASE_INSENSITIVE;
    }
    if ((options & NSRegularExpressionAllowCommentsAndWhitespace) != 0)
    {
        flags |= UREGEX_COMMENTS;
    }
    if ((options & NSRegularExpressionDotMatchesLineSeparators) != 0)
    {
        flags |= UREGEX_DOTALL;
    }
    if ((options & NSRegularExpressionAnchorsMatchLines) != 0)
    {
        flags |= UREGEX_MULTILINE;
    }
    if ((options & NSRegularExpressionUseUnixLineSeparators) != 0)
    {
        flags |= UREGEX_UNIX_LINES;
    }
    if ((options & NSRegularExpressionUseUnicodeWordBoundaries) != 0)
    {
        flags |= UREGEX_UWORD;
    }
    return flags;
}

[[nodiscard]] UChar* TRCopyCharacters(NSString* string, int32_t* length)
{
    NSUInteger const nsLength = [string length];
    if (nsLength > static_cast<NSUInteger>(INT32_MAX))
    {
        return nullptr;
    }

    size_t const byteCount = std::max<NSUInteger>(nsLength, 1) * sizeof(UChar);
    UChar* characters = static_cast<UChar*>(std::malloc(byteCount));
    if (characters == nullptr)
    {
        return nullptr;
    }

    if (nsLength != 0)
    {
        [string getCharacters:reinterpret_cast<unichar*>(characters) range:NSMakeRange(0, nsLength)];
    }
    else
    {
        characters[0] = 0;
    }

    *length = static_cast<int32_t>(nsLength);
    return characters;
}

[[nodiscard]] NSMatchingFlags TRMatchFlags(URegularExpression* regex)
{
    UErrorCode status = U_ZERO_ERROR;
    BOOL const hitEnd = uregex_hitEnd(regex, &status) != 0 && status <= U_ZERO_ERROR;
    status = U_ZERO_ERROR;
    BOOL const requireEnd = uregex_requireEnd(regex, &status) != 0 && status <= U_ZERO_ERROR;

    NSMatchingFlags flags = 0;
    if (hitEnd)
    {
        flags |= NSMatchingHitEnd;
    }
    if (requireEnd)
    {
        flags |= NSMatchingRequiredEnd;
    }
    return flags;
}

struct TRMatchCallbackContext
{
    TRNSMatchingBlock block;
    BOOL* stopped;
};

UBool TRRegexMatchCallback(void const* rawContext, int32_t /*steps*/)
{
    auto const* context = static_cast<TRMatchCallbackContext const*>(rawContext);
    if (context == nullptr || context->block == nil)
    {
        return 1;
    }

    BOOL stop = NO;
    context->block(nil, NSMatchingProgress, &stop);
    if (stop)
    {
        *context->stopped = YES;
        return 0;
    }
    return 1;
}

UBool TRRegexFindProgressCallback(void const* rawContext, int64_t /*matchIndex*/)
{
    auto const* context = static_cast<TRMatchCallbackContext const*>(rawContext);
    if (context == nullptr || context->block == nil)
    {
        return 1;
    }

    BOOL stop = NO;
    context->block(nil, NSMatchingProgress, &stop);
    if (stop)
    {
        *context->stopped = YES;
        return 0;
    }
    return 1;
}

using TRSetFindProgressCallbackFunc = void (*)(
    URegularExpression* regex,
    UBool (*callback)(void const*, int64_t),
    void const* context,
    UErrorCode* status);

[[nodiscard]] TRSetFindProgressCallbackFunc TRGetSetFindProgressCallback()
{
    static TRSetFindProgressCallbackFunc callback = reinterpret_cast<TRSetFindProgressCallbackFunc>(
        dlsym(RTLD_DEFAULT, "uregex_setFindProgressCallback"));
    return callback;
}

[[nodiscard]] Class TRRealRegularExpressionClass()
{
    return NSClassFromString(@"NSRegularExpression");
}

[[nodiscard]] Class TRRealDataDetectorClass()
{
    return NSClassFromString(@"NSDataDetector");
}

[[nodiscard]] id TRCallRealRegularExpressionFactory(
    NSString* pattern,
    NSRegularExpressionOptions options,
    NSError** error)
{
    Class realClass = TRRealRegularExpressionClass();
    if (realClass == Nil)
    {
        return nil;
    }

    SEL const selector = @selector(regularExpressionWithPattern:options:error:);
    using FactoryFunc = id (*)(id, SEL, NSString*, NSRegularExpressionOptions, NSError**);
    return reinterpret_cast<FactoryFunc>([realClass methodForSelector:selector])(realClass, selector, pattern, options, error);
}

[[nodiscard]] id TRCallRealRegularExpressionInit(
    id object,
    NSString* pattern,
    NSRegularExpressionOptions options,
    NSError** error)
{
    SEL const selector = @selector(initWithPattern:options:error:);
    using InitFunc = id (*)(id, SEL, NSString*, NSRegularExpressionOptions, NSError**);
    return reinterpret_cast<InitFunc>([object methodForSelector:selector])(object, selector, pattern, options, error);
}

[[nodiscard]] id TRCallRealDataDetectorFactory(uint64_t checkingTypes, NSError** error)
{
    Class realClass = TRRealDataDetectorClass();
    if (realClass == Nil)
    {
        return nil;
    }

    SEL const selector = @selector(dataDetectorWithTypes:error:);
    using FactoryFunc = id (*)(id, SEL, uint64_t, NSError**);
    return reinterpret_cast<FactoryFunc>([realClass methodForSelector:selector])(realClass, selector, checkingTypes, error);
}

[[nodiscard]] NSRange TRRangeByAddingOffset(NSRange range, NSInteger offset)
{
    if (range.location == NSNotFound)
    {
        return range;
    }

    if (offset < 0 && range.location < static_cast<NSUInteger>(-offset))
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"%ld invalid offset for range %@", static_cast<long>(offset), NSStringFromRange(range)];
    }

    range.location += offset;
    return range;
}

} // namespace

@interface TRRegularExpressionCheckingResult : NSTextCheckingResult
{
    NSArray* _ranges;
    NSRegularExpression* _regularExpression;
}
- (instancetype)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression*)regularExpression;
- (instancetype)initWithRangeArray:(NSArray*)ranges regularExpression:(NSRegularExpression*)regularExpression;
@end

@implementation TRRegularExpressionCheckingResult

- (instancetype)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression*)regularExpression
{
    if (count == 0)
    {
        [NSException raise:NSInvalidArgumentException format:@"%@: must have at least one range", NSStringFromSelector(_cmd)];
    }

    NSMutableArray* rangeValues = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; ++i)
    {
        [rangeValues addObject:[NSValue valueWithRange:ranges[i]]];
    }

    return [self initWithRangeArray:rangeValues regularExpression:regularExpression];
}

- (instancetype)initWithRangeArray:(NSArray*)ranges regularExpression:(NSRegularExpression*)regularExpression
{
    if ((self = [super init]) != nil)
    {
        _ranges = [ranges copy];
        _regularExpression = [regularExpression copy];
    }
    return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_ranges release];
    [_regularExpression release];
    [super dealloc];
}
#endif

- (id)copyWithZone:(NSZone*)zone
{
#if __has_feature(objc_arc)
    return self;
#else
    return [self retain];
#endif
}

- (NSTextCheckingType)resultType
{
    return static_cast<NSTextCheckingType>(NSTextCheckingTypeRegularExpressionLegacy);
}

- (NSRange)range
{
    return [self rangeAtIndex:0];
}

- (NSUInteger)numberOfRanges
{
    return [_ranges count];
}

- (NSRange)rangeAtIndex:(NSUInteger)idx
{
    if (idx >= [_ranges count])
    {
        [NSException raise:NSRangeException format:@"%@: index out of bounds", NSStringFromSelector(_cmd)];
    }

    return [[_ranges objectAtIndex:idx] rangeValue];
}

- (NSArray*)rangeArray
{
    return _ranges;
}

- (NSRegularExpression*)regularExpression
{
    return _regularExpression;
}

- (id)resultByAdjustingRangesWithOffset:(NSInteger)offset
{
    NSMutableArray* adjustedRanges = [NSMutableArray arrayWithCapacity:[_ranges count]];
    for (NSValue* rangeValue in _ranges)
    {
        [adjustedRanges addObject:[NSValue valueWithRange:TRRangeByAddingOffset([rangeValue rangeValue], offset)]];
    }

    return TR_AUTORELEASE([[[self class] alloc] initWithRangeArray:adjustedRanges regularExpression:_regularExpression]);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<%@ %p>{%@}", [self class], self, _ranges];
}

@end

static NSTextCheckingResult* TRRegularExpressionCheckingResultWithRanges(
    NSRangePointer ranges,
    NSUInteger count,
    NSRegularExpression* regularExpression)
{
    return TR_AUTORELEASE([[TRRegularExpressionCheckingResult alloc] initWithRanges:ranges count:count regularExpression:regularExpression]);
}

#if !TR_MACOS_OBJC_FRAGILE_RUNTIME
@interface NSRegularExpression ()
{
    NSString* _pattern;
    NSRegularExpressionOptions _options;
    URegularExpression* _regex;
}
@end
#endif

@implementation NSRegularExpression

+ (NSString*)escapedPatternForString:(NSString*)string
{
    Class realClass = TRRealRegularExpressionClass();
    if (realClass != Nil)
    {
        SEL const selector = @selector(escapedPatternForString:);
        using EscapeFunc = NSString* (*)(id, SEL, NSString*);
        return reinterpret_cast<EscapeFunc>([realClass methodForSelector:selector])(realClass, selector, string);
    }

    return TREscapeString(string, @"*?+[(){}^$|\\./");
}

+ (NSString*)escapedTemplateForString:(NSString*)string
{
    Class realClass = TRRealRegularExpressionClass();
    if (realClass != Nil)
    {
        SEL const selector = @selector(escapedTemplateForString:);
        using EscapeFunc = NSString* (*)(id, SEL, NSString*);
        return reinterpret_cast<EscapeFunc>([realClass methodForSelector:selector])(realClass, selector, string);
    }

    return TREscapeString(string, @"\\$");
}

+ (instancetype)regularExpressionWithPattern:(NSString*)pattern options:(NSRegularExpressionOptions)options error:(NSError**)error
{
    id realExpression = TRCallRealRegularExpressionFactory(pattern, options, error);
    if (realExpression != nil)
    {
        return realExpression;
    }

    return TR_AUTORELEASE([[self alloc] initWithPattern:pattern options:options error:error]);
}

- (instancetype)initWithPattern:(NSString*)pattern options:(NSRegularExpressionOptions)options error:(NSError**)error
{
    Class realClass = TRRealRegularExpressionClass();
    if (realClass != Nil && ![self isKindOfClass:realClass])
    {
        id realExpression = TRCallRealRegularExpressionInit([realClass alloc], pattern, options, error);
#if !__has_feature(objc_arc)
        [self release];
#endif
        return realExpression;
    }

    if (pattern == nil)
    {
        TRRaiseNilArgument(self, _cmd);
    }

    if ((self = [super init]) == nil)
    {
        return nil;
    }

    NSString* compilePattern = (options & NSRegularExpressionIgnoreMetacharacters) != 0 ?
        [NSRegularExpression escapedPatternForString:pattern] :
        pattern;

    int32_t patternLength = 0;
    UChar* patternCharacters = TRCopyCharacters(compilePattern, &patternLength);
    if (patternCharacters != nullptr)
    {
        UErrorCode status = U_ZERO_ERROR;
        _regex = uregex_open(patternCharacters, patternLength, TRICUFlags(options), nullptr, &status);
        std::free(patternCharacters);

        if (status <= U_ZERO_ERROR && _regex != nullptr)
        {
            _pattern = [pattern copy];
            _options = options;
            return self;
        }
    }

    if (error != nullptr)
    {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObject:compilePattern forKey:TRNSInvalidValueErrorKey];
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:2048 userInfo:userInfo];
    }

#if !__has_feature(objc_arc)
    [self release];
#endif
    return nil;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_pattern release];
    if (_regex != nullptr)
    {
        uregex_close(_regex);
    }
    [super dealloc];
}
#else
- (void)dealloc
{
    if (_regex != nullptr)
    {
        uregex_close(_regex);
    }
}
#endif

- (id)copyWithZone:(NSZone*)zone
{
#if __has_feature(objc_arc)
    return self;
#else
    return [self retain];
#endif
}

- (NSString*)pattern
{
    return _pattern;
}

- (NSRegularExpressionOptions)options
{
    return _options;
}

- (NSUInteger)numberOfCaptureGroups
{
    UErrorCode status = U_ZERO_ERROR;
    int32_t const count = uregex_groupCount(_regex, &status);
    return status <= U_ZERO_ERROR && count > 0 ? static_cast<NSUInteger>(count) : 0U;
}

- (NSUInteger)hash
{
    return [_pattern hash] ^ _options;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
    {
        return YES;
    }

    NSRegularExpression* other = static_cast<NSRegularExpression*>(object);
    return [other isKindOfClass:[NSRegularExpression class]] && [[other pattern] isEqual:_pattern] && [other options] == _options;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@ 0x%lx", [super description], _pattern, static_cast<unsigned long>(_options)];
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    if ([coder allowsKeyedCoding])
    {
        [coder encodeObject:_pattern forKey:@"NSPattern"];
        [coder encodeInt64:_options forKey:@"NSOptions"];
    }
    else
    {
        uint64_t options = _options;
        [coder encodeObject:_pattern];
        [coder encodeValueOfObjCType:"Q" at:&options];
    }
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
    NSError* error = nil;
    if ([coder allowsKeyedCoding])
    {
        return [self initWithPattern:[coder decodeObjectForKey:@"NSPattern"] options:[coder decodeInt64ForKey:@"NSOptions"] error:&error];
    }

    NSInteger const version = [coder versionForClassName:@"NSRegularExpression"];
    if (version <= 0 || version > 1)
    {
#if !__has_feature(objc_arc)
        [self release];
#endif
        return nil;
    }

    NSString* pattern = [coder decodeObject];
    uint64_t options = 0;
    [coder decodeValueOfObjCType:"Q" at:&options];
    return [self initWithPattern:pattern options:options error:&error];
}

- (void)enumerateMatchesInString:(NSString*)string
                         options:(NSMatchingOptions)options
                           range:(NSRange)range
                      usingBlock:(TRNSMatchingBlock)block
{
    if (string == nil || block == nil)
    {
        TRRaiseNilArgument(self, _cmd);
    }
    if (!TRRangeIsValid(string, range))
    {
        TRRaiseRangeException(self, _cmd);
    }

    BOOL stopped = NO;
    NSMatchingFlags completionFlags = NSMatchingCompleted;
    BOOL attemptedMatch = NO;

    UErrorCode status = U_ZERO_ERROR;
    URegularExpression* regex = nullptr;
    int32_t stringLength = 0;
    UChar* characters = nullptr;

    if (range.location > static_cast<NSUInteger>(INT32_MAX) || NSMaxRange(range) > static_cast<NSUInteger>(INT32_MAX))
    {
        completionFlags |= NSMatchingInternalError;
        goto completion;
    }

    regex = uregex_clone(_regex, &status);
    if (status > U_ZERO_ERROR || regex == nullptr)
    {
        completionFlags |= NSMatchingInternalError;
        goto completion;
    }

    characters = TRCopyCharacters(string, &stringLength);
    if (characters == nullptr)
    {
        completionFlags |= NSMatchingInternalError;
        uregex_close(regex);
        goto completion;
    }

    status = U_ZERO_ERROR;
    uregex_setText(regex, characters, stringLength, &status);
    uregex_setRegion(regex, static_cast<int32_t>(range.location), static_cast<int32_t>(NSMaxRange(range)), &status);
    if ((options & NSMatchingWithTransparentBounds) != 0)
    {
        uregex_useTransparentBounds(regex, 1, &status);
    }
    if ((options & NSMatchingWithoutAnchoringBounds) != 0)
    {
        uregex_useAnchoringBounds(regex, 0, &status);
    }
    if ((options & NSMatchingReportProgress) != 0)
    {
        TRMatchCallbackContext context = { block, &stopped };
        uregex_setMatchCallback(regex, TRRegexMatchCallback, &context, &status);
        if (TRSetFindProgressCallbackFunc findProgressCallback = TRGetSetFindProgressCallback())
        {
            findProgressCallback(regex, TRRegexFindProgressCallback, &context, &status);
        }
    }

    if (status > U_ZERO_ERROR)
    {
        completionFlags |= NSMatchingInternalError;
    }
    else
    {
        NSUInteger allowedStart = range.location;
        NSUInteger const captureCount = [self numberOfCaptureGroups];
        NSUInteger const rangeCount = captureCount + 1;

        while (!stopped)
        {
            status = U_ZERO_ERROR;
            attemptedMatch = YES;
            if (uregex_findNext(regex, &status) == 0 || (status > U_ZERO_ERROR && status != U_REGEX_STOPPED_BY_CALLER))
            {
                if (status > U_ZERO_ERROR && status != U_REGEX_STOPPED_BY_CALLER)
                {
                    completionFlags |= NSMatchingInternalError;
                }
                break;
            }
            if (stopped || status == U_REGEX_STOPPED_BY_CALLER)
            {
                break;
            }

            status = U_ZERO_ERROR;
            int32_t const matchStart = uregex_start(regex, 0, &status);
            int32_t const matchEnd = uregex_end(regex, 0, &status);
            if (status > U_ZERO_ERROR)
            {
                completionFlags |= NSMatchingInternalError;
                break;
            }

            if ((options & NSMatchingAnchored) != 0)
            {
                if (static_cast<NSUInteger>(matchStart) > allowedStart)
                {
                    break;
                }
                allowedStart = static_cast<NSUInteger>(matchEnd);
            }

            NSTextCheckingResult* result = nil;
            if ((options & TRMatchingSkipResultObjects) == 0)
            {
                NSRange* ranges = static_cast<NSRange*>(std::calloc(rangeCount, sizeof(NSRange)));
                if (ranges == nullptr)
                {
                    completionFlags |= NSMatchingInternalError;
                    break;
                }

                for (NSUInteger i = 0; i < rangeCount; ++i)
                {
                    status = U_ZERO_ERROR;
                    int32_t const start = uregex_start(regex, static_cast<int32_t>(i), &status);
                    int32_t const end = uregex_end(regex, static_cast<int32_t>(i), &status);
                    if (status <= U_ZERO_ERROR && start >= 0 && end >= start)
                    {
                        ranges[i] = NSMakeRange(static_cast<NSUInteger>(start), static_cast<NSUInteger>(end - start));
                    }
                    else
                    {
                        ranges[i] = NSMakeRange(NSNotFound, 0);
                    }
                }

                result = TRRegularExpressionCheckingResultWithRanges(ranges, rangeCount, self);
                std::free(ranges);
            }

            BOOL stop = NO;
            block(result, TRMatchFlags(regex), &stop);
            stopped = stop;
        }
    }

    if (attemptedMatch && (completionFlags & NSMatchingInternalError) == 0)
    {
        completionFlags |= TRMatchFlags(regex);
    }

    if ((options & NSMatchingReportProgress) != 0)
    {
        status = U_ZERO_ERROR;
        uregex_setMatchCallback(regex, nullptr, nullptr, &status);
        if (TRSetFindProgressCallbackFunc findProgressCallback = TRGetSetFindProgressCallback())
        {
            findProgressCallback(regex, nullptr, nullptr, &status);
        }
    }

    std::free(characters);
    uregex_close(regex);

completion:
    if ((options & NSMatchingReportCompletion) != 0 && !stopped)
    {
        BOOL completionStop = NO;
        block(nil, completionFlags, &completionStop);
    }
}

- (NSArray*)matchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range
{
    NSMutableArray* results = [NSMutableArray array];
    [self enumerateMatchesInString:string options:(options & ~(NSMatchingReportProgress | NSMatchingReportCompletion)) range:range usingBlock:
        ^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
            (void)flags;
            (void)stop;
            if (result != nil)
            {
                [results addObject:result];
            }
        }];
    return results;
}

- (NSUInteger)numberOfMatchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range
{
    __block NSUInteger count = 0;
    [self enumerateMatchesInString:string options:(options & ~(NSMatchingReportProgress | NSMatchingReportCompletion)) | TRMatchingSkipResultObjects range:range usingBlock:
        ^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
            (void)result;
            (void)flags;
            (void)stop;
            ++count;
        }];
    return count;
}

- (NSTextCheckingResult*)firstMatchInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range
{
    __block NSTextCheckingResult* firstMatch = nil;
    [self enumerateMatchesInString:string options:(options & ~(NSMatchingReportProgress | NSMatchingReportCompletion)) range:range usingBlock:
        ^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
            (void)flags;
            firstMatch = result;
            *stop = YES;
        }];
    return firstMatch;
}

- (NSRange)rangeOfFirstMatchInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range
{
    NSTextCheckingResult* result = [self firstMatchInString:string options:options range:range];
    return result == nil ? NSMakeRange(NSNotFound, 0) : [result range];
}

- (NSString*)replacementStringForResult:(NSTextCheckingResult*)result
                               inString:(NSString*)string
                                 offset:(NSInteger)offset
                               template:(NSString*)templ
{
    if (result == nil || string == nil || templ == nil)
    {
        TRRaiseNilArgument(self, _cmd);
    }

    NSCharacterSet* markerSet = [NSCharacterSet characterSetWithCharactersInString:@"\\$"];
    NSRange markerRange = [templ rangeOfCharacterFromSet:markerSet];
    if (markerRange.length == 0)
    {
        return templ;
    }

    NSMutableString* replacement = [NSMutableString stringWithString:templ];
    NSUInteger largestGroup = [result numberOfRanges] == 0 ? 0 : [result numberOfRanges] - 1;
    NSUInteger maxDigits = 1;
    while (largestGroup >= 10)
    {
        largestGroup /= 10;
        ++maxDigits;
    }

    while (markerRange.length != 0)
    {
        unichar const marker = [replacement characterAtIndex:markerRange.location];
        if (marker == '\\')
        {
            [replacement deleteCharactersInRange:markerRange];
        }
        else if (marker == '$')
        {
            NSUInteger digitLocation = NSMaxRange(markerRange);
            NSUInteger group = 0;
            NSUInteger digitCount = 0;
            while (digitLocation < [replacement length] && digitCount < maxDigits)
            {
                unichar const ch = [replacement characterAtIndex:digitLocation];
                if (ch < '0' || ch > '9')
                {
                    break;
                }
                group = group * 10 + (ch - '0');
                ++digitLocation;
                ++digitCount;
            }

            if (digitCount != 0)
            {
                NSString* groupString = @"";
                if (group < [result numberOfRanges])
                {
                    NSRange groupRange = [result rangeAtIndex:group];
                    groupRange = TRRangeByAddingOffset(groupRange, offset);
                    if (groupRange.location != NSNotFound && groupRange.length != 0)
                    {
                        groupString = [string substringWithRange:groupRange];
                    }
                }

                [replacement replaceCharactersInRange:NSMakeRange(markerRange.location, digitCount + 1) withString:groupString];
            }
        }

        NSUInteger const nextLocation = NSMaxRange(markerRange);
        if (nextLocation >= [replacement length])
        {
            break;
        }
        markerRange = [replacement rangeOfCharacterFromSet:markerSet options:0 range:NSMakeRange(nextLocation, [replacement length] - nextLocation)];
    }

    return replacement;
}

- (NSString*)stringByReplacingMatchesInString:(NSString*)string
                                      options:(NSMatchingOptions)options
                                        range:(NSRange)range
                                 withTemplate:(NSString*)templ
{
    if (string == nil || templ == nil)
    {
        TRRaiseNilArgument(self, _cmd);
    }

    NSMutableString* resultString = [NSMutableString stringWithString:string];
    [self replaceMatchesInString:resultString options:options range:range withTemplate:templ];
    return resultString;
}

- (NSUInteger)replaceMatchesInString:(NSMutableString*)string
                              options:(NSMatchingOptions)options
                                range:(NSRange)range
                         withTemplate:(NSString*)templ
{
    if (string == nil || templ == nil)
    {
        TRRaiseNilArgument(self, _cmd);
    }

    NSArray* matches = [self matchesInString:string options:options range:range];
    NSInteger offset = 0;
    NSUInteger replacementCount = 0;

    for (NSTextCheckingResult* match in matches)
    {
        NSRange matchRange = [match range];
        NSString* replacement = [self replacementStringForResult:match inString:string offset:offset template:templ];
        matchRange.location += offset;
        [string replaceCharactersInRange:matchRange withString:replacement];
        offset += static_cast<NSInteger>([replacement length]) - static_cast<NSInteger>(matchRange.length);
        ++replacementCount;
    }

    return replacementCount;
}

@end

#if !TR_MACOS_OBJC_FRAGILE_RUNTIME
@interface NSDataDetector ()
{
    uint64_t _checkingTypes;
}
@end
#endif

@implementation NSDataDetector

+ (instancetype)dataDetectorWithTypes:(uint64_t)checkingTypes error:(NSError**)error
{
    id realDetector = TRCallRealDataDetectorFactory(checkingTypes, error);
    if (realDetector != nil)
    {
        return realDetector;
    }

    NSDataDetector* detector = TR_AUTORELEASE([[self alloc] initWithPattern:@"https?://[^\\p{Z}\\v]+" options:0 error:error]);
    detector->_checkingTypes = checkingTypes;
    return detector;
}

- (NSArray*)matchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range
{
    NSArray* matches = [super matchesInString:string options:options range:range];
    NSMutableArray* linkMatches = [NSMutableArray arrayWithCapacity:[matches count]];

    for (NSTextCheckingResult* match in matches)
    {
        NSRange matchRange = [match range];
        NSURL* url = [NSURL URLWithString:[string substringWithRange:matchRange]];
        if (url != nil)
        {
            [linkMatches addObject:[NSTextCheckingResult linkCheckingResultWithRange:matchRange URL:url]];
        }
    }

    return linkMatches;
}

@end

#endif
