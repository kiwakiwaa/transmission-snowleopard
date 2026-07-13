// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

#include <float.h>
#include <limits.h>
#include <stdint.h>

#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif

#define NSIntegerMax LONG_MAX
#define NSIntegerMin LONG_MIN
#define NSUIntegerMax ULONG_MAX

#define NSINTEGER_DEFINED 1
#endif

#ifndef CGFLOAT_DEFINED
#if defined(__LP64__) && __LP64__
#define CGFLOAT_TYPE double
#define CGFLOAT_IS_DOUBLE 1
#define CGFLOAT_MIN DBL_MIN
#define CGFLOAT_MAX DBL_MAX
#else
#define CGFLOAT_TYPE float
#define CGFLOAT_IS_DOUBLE 0
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#endif

typedef CGFLOAT_TYPE CGFloat;
#define CGFLOAT_DEFINED 1
#endif

#if TR_MACOS_SDK_BEFORE_10_6

enum
{
    NSTextCheckingTypeOrthography = 1ULL << 0,
    NSTextCheckingTypeSpelling = 1ULL << 1,
    NSTextCheckingTypeGrammar = 1ULL << 2,
    NSTextCheckingTypeDate = 1ULL << 3,
    NSTextCheckingTypeAddress = 1ULL << 4,
    NSTextCheckingTypeLink = 1ULL << 5,
    NSTextCheckingTypeQuote = 1ULL << 6,
    NSTextCheckingTypeDash = 1ULL << 7,
    NSTextCheckingTypeReplacement = 1ULL << 8,
    NSTextCheckingTypeCorrection = 1ULL << 9
};
typedef uint64_t NSTextCheckingType;

enum
{
    NSTextCheckingAllSystemTypes = 0xffffffffULL,
    NSTextCheckingAllCustomTypes = 0xffffffffULL << 32,
    NSTextCheckingAllTypes = NSTextCheckingAllSystemTypes | NSTextCheckingAllCustomTypes
};
typedef uint64_t NSTextCheckingTypes;

@class NSURL;

@interface NSTextCheckingResult : NSObject<NSCopying, NSCoding>
{
  @private
    NSTextCheckingType _resultType;
    NSRange _range;
    NSURL* _URL;
}

@property(nonatomic, readonly) NSTextCheckingType resultType;
@property(nonatomic, readonly) NSRange range;
@property(nonatomic, readonly, retain) NSURL* URL;

+ (NSTextCheckingResult*)linkCheckingResultWithRange:(NSRange)range URL:(NSURL*)url;
- (instancetype)initWithResultType:(NSTextCheckingType)resultType range:(NSRange)range URL:(NSURL*)url;

@end

#endif
