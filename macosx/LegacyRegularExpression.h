// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_7

typedef NSUInteger NSRegularExpressionOptions;
typedef NSUInteger NSMatchingOptions;
typedef NSUInteger NSMatchingFlags;

enum
{
    NSRegularExpressionCaseInsensitive = 1 << 0,
    NSRegularExpressionAllowCommentsAndWhitespace = 1 << 1,
    NSRegularExpressionIgnoreMetacharacters = 1 << 2,
    NSRegularExpressionDotMatchesLineSeparators = 1 << 3,
    NSRegularExpressionAnchorsMatchLines = 1 << 4,
    NSRegularExpressionUseUnixLineSeparators = 1 << 5,
    NSRegularExpressionUseUnicodeWordBoundaries = 1 << 6,
};

enum
{
    NSMatchingReportProgress = 1 << 0,
    NSMatchingReportCompletion = 1 << 1,
    NSMatchingAnchored = 1 << 2,
    NSMatchingWithTransparentBounds = 1 << 3,
    NSMatchingWithoutAnchoringBounds = 1 << 4,
};

enum
{
    NSMatchingProgress = 1 << 0,
    NSMatchingCompleted = 1 << 1,
    NSMatchingHitEnd = 1 << 2,
    NSMatchingRequiredEnd = 1 << 3,
    NSMatchingInternalError = 1 << 4,
};

@class TRLegacyRegularExpression;

typedef void (^TRNSMatchingBlock)(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop);

@interface TRLegacyRegularExpression : NSObject <NSCopying, NSCoding>
+ (NSString*)escapedPatternForString:(NSString*)string;
+ (NSString*)escapedTemplateForString:(NSString*)string;
+ (instancetype)regularExpressionWithPattern:(NSString*)pattern options:(NSRegularExpressionOptions)options error:(NSError**)error;
- (instancetype)initWithPattern:(NSString*)pattern options:(NSRegularExpressionOptions)options error:(NSError**)error;
- (NSString*)pattern;
- (NSRegularExpressionOptions)options;
- (NSUInteger)numberOfCaptureGroups;
- (void)enumerateMatchesInString:(NSString*)string
                         options:(NSMatchingOptions)options
                           range:(NSRange)range
                      usingBlock:(TRNSMatchingBlock)block;
- (NSArray*)matchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSUInteger)numberOfMatchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSTextCheckingResult*)firstMatchInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSRange)rangeOfFirstMatchInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSString*)stringByReplacingMatchesInString:(NSString*)string
                                      options:(NSMatchingOptions)options
                                        range:(NSRange)range
                                 withTemplate:(NSString*)templ;
- (NSUInteger)replaceMatchesInString:(NSMutableString*)string
                              options:(NSMatchingOptions)options
                                range:(NSRange)range
                         withTemplate:(NSString*)templ;
- (NSString*)replacementStringForResult:(NSTextCheckingResult*)result
                               inString:(NSString*)string
                                 offset:(NSInteger)offset
                               template:(NSString*)templ;
@end

@interface NSTextCheckingResult (TRLegacyRegularExpression)
- (NSUInteger)numberOfRanges;
- (NSRange)rangeAtIndex:(NSUInteger)idx;
- (TRLegacyRegularExpression*)regularExpression;
@end

@interface TRLegacyDataDetector : TRLegacyRegularExpression
+ (instancetype)dataDetectorWithTypes:(uint64_t)checkingTypes error:(NSError**)error;
@end

#define NSRegularExpression TRLegacyRegularExpression
#define NSDataDetector TRLegacyDataDetector

#endif
