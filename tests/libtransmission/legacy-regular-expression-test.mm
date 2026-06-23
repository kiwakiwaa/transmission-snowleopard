// This file Copyright © Transmission authors and contributors.
// It may be used under GPLv2 (SPDX: GPL-2.0-only), GPLv3 (SPDX: GPL-3.0-only),
// or any future license endorsed by Mnemosyne LLC.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <gtest/gtest.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_7
#import "LegacyRegularExpression.h"
#endif

#include "test-fixtures.h"

using LegacyRegularExpressionTest = ::tr::test::TransmissionTest;

#if TR_MACOS_SDK_BEFORE_10_7
TEST_F(LegacyRegularExpressionTest, UsesFoundationImplementationWhenRuntimeProvidesIt)
{
    @autoreleasepool
    {
        Class realRegularExpressionClass = NSClassFromString(@"NSRegularExpression");
        if (realRegularExpressionClass == Nil)
        {
            return;
        }

        NSError* error = nil;
        id regex = [NSRegularExpression regularExpressionWithPattern:@"a" options:0 error:&error];
        ASSERT_TRUE(regex != nil);
        EXPECT_TRUE(error == nil);
        EXPECT_TRUE([regex isKindOfClass:realRegularExpressionClass]);

        Class realDataDetectorClass = NSClassFromString(@"NSDataDetector");
        ASSERT_TRUE(realDataDetectorClass != Nil);
        id detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
        ASSERT_TRUE(detector != nil);
        EXPECT_TRUE([detector isKindOfClass:realDataDetectorClass]);
    }
}
#endif

TEST_F(LegacyRegularExpressionTest, ConstructionAndBasicMatching)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"(magnet):\\?([^\\p{Z}\\v]+)"
                                                                               options:0
                                                                                 error:&error];
        ASSERT_TRUE(regex != nil);
        EXPECT_TRUE(error == nil);
        EXPECT_TRUE([[regex pattern] isEqualToString:@"(magnet):\\?([^\\p{Z}\\v]+)"]);
        EXPECT_EQ(2U, [regex numberOfCaptureGroups]);

        NSString* string = @"open magnet:?xt=urn:btih:abc now";
        NSArray* matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
        ASSERT_EQ(1U, [matches count]);

        NSTextCheckingResult* result = [matches objectAtIndex:0];
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(5, 23), [result range]));
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(5, 6), [result rangeAtIndex:1]));
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(13, 15), [result rangeAtIndex:2]));
        EXPECT_EQ(regex, [result regularExpression]);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSData* archived = [NSKeyedArchiver archivedDataWithRootObject:regex];
        NSRegularExpression* unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
#pragma clang diagnostic pop
        EXPECT_TRUE([unarchived isEqual:regex]);
        EXPECT_TRUE([[unarchived pattern] isEqualToString:[regex pattern]]);
        EXPECT_EQ([regex options], [unarchived options]);
    }
}

TEST_F(LegacyRegularExpressionTest, Options)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSString* string = @"A\nb";

        NSRegularExpression* insensitive = [NSRegularExpression regularExpressionWithPattern:@"a"
                                                                                     options:NSRegularExpressionCaseInsensitive
                                                                                       error:&error];
        ASSERT_TRUE(insensitive != nil);
        EXPECT_EQ(1U, [insensitive numberOfMatchesInString:string options:0 range:NSMakeRange(0, [string length])]);

        NSRegularExpression* dotAll = [NSRegularExpression regularExpressionWithPattern:@"A.b"
                                                                                options:NSRegularExpressionDotMatchesLineSeparators
                                                                                  error:&error];
        ASSERT_TRUE(dotAll != nil);
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(0, 3), [dotAll rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])]));

        NSRegularExpression* literal = [NSRegularExpression regularExpressionWithPattern:@"a+b"
                                                                                 options:NSRegularExpressionIgnoreMetacharacters
                                                                                   error:&error];
        ASSERT_TRUE(literal != nil);
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(2, 3), [literal rangeOfFirstMatchInString:@"xxa+b" options:0 range:NSMakeRange(0, 5)]));
    }
}

TEST_F(LegacyRegularExpressionTest, EnumerationStopAndCompletion)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"\\w+"
                                                                               options:0
                                                                                 error:&error];
        ASSERT_TRUE(regex != nil);

        __block NSUInteger matches = 0;
        __block NSUInteger completions = 0;
        [regex enumerateMatchesInString:@"one two three"
                                options:NSMatchingReportCompletion
                                  range:NSMakeRange(0, 13)
                             usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
                                 (void)result;
                                 (void)stop;
                                 if ((flags & NSMatchingCompleted) != 0)
                                 {
                                     ++completions;
                                     return;
                                 }

                                 ASSERT_TRUE(result != nil);
                                 ++matches;
                                 if (matches == 2)
                                 {
                                     *stop = YES;
                                 }
                             }];

        EXPECT_EQ(2U, matches);
        EXPECT_EQ(0U, completions);

        matches = 0;
        completions = 0;
        [regex enumerateMatchesInString:@"one two"
                                options:NSMatchingReportCompletion
                                  range:NSMakeRange(0, 7)
                             usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
                                 (void)result;
                                 (void)stop;
                                 if ((flags & NSMatchingCompleted) != 0)
                                 {
                                     ++completions;
                                 }
                                 else
                                 {
                                     ++matches;
                                 }
                             }];

        EXPECT_EQ(2U, matches);
        EXPECT_EQ(1U, completions);
    }
}

TEST_F(LegacyRegularExpressionTest, AnchoredAndRanges)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+"
                                                                               options:0
                                                                                 error:&error];
        ASSERT_TRUE(regex != nil);

        NSString* string = @"abc 123";
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(4, 3), [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])]));
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(NSNotFound, 0), [regex rangeOfFirstMatchInString:string
                                                                                       options:NSMatchingAnchored
                                                                                         range:NSMakeRange(0, [string length])]));
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(4, 3), [regex rangeOfFirstMatchInString:string
                                                                              options:NSMatchingAnchored
                                                                                range:NSMakeRange(4, 3)]));
    }
}

TEST_F(LegacyRegularExpressionTest, ReplacementTemplates)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"(\\w+)-(\\d+)"
                                                                               options:0
                                                                                 error:&error];
        ASSERT_TRUE(regex != nil);

        NSString* input = @"alpha-12 beta-34";
        NSString* replaced = [regex stringByReplacingMatchesInString:input
                                                             options:0
                                                               range:NSMakeRange(0, [input length])
                                                        withTemplate:@"$2/$1"];
        EXPECT_TRUE([replaced isEqualToString:@"12/alpha 34/beta"]);

        NSTextCheckingResult* first = [regex firstMatchInString:input options:0 range:NSMakeRange(0, [input length])];
        EXPECT_TRUE([[regex replacementStringForResult:first inString:input offset:0 template:@"\\$1=$1,$9"] isEqualToString:@"$1=alpha,"]);

        NSRegularExpression* nineGroups = [NSRegularExpression regularExpressionWithPattern:@"(a)(b)(c)(d)(e)(f)(g)(h)(i)"
                                                                                    options:0
                                                                                      error:&error];
        ASSERT_TRUE(nineGroups != nil);
        NSTextCheckingResult* nineGroupMatch = [nineGroups firstMatchInString:@"abcdefghi" options:0 range:NSMakeRange(0, 9)];
        EXPECT_TRUE([[nineGroups replacementStringForResult:nineGroupMatch inString:@"abcdefghi" offset:0 template:@"$10"] isEqualToString:@"a0"]);

        NSMutableString* mutableInput = [NSMutableString stringWithString:input];
        EXPECT_EQ(2U, [regex replaceMatchesInString:mutableInput options:0 range:NSMakeRange(0, [mutableInput length]) withTemplate:@"$1"]);
        EXPECT_TRUE([mutableInput isEqualToString:@"alpha beta"]);
    }
}

TEST_F(LegacyRegularExpressionTest, Escaping)
{
    @autoreleasepool
    {
        EXPECT_TRUE([[NSRegularExpression escapedPatternForString:@"a+b/c"] isEqualToString:@"a\\+b\\/c"]);
        EXPECT_TRUE([[NSRegularExpression escapedTemplateForString:@"$1\\x"] isEqualToString:@"\\$1\\\\x"]);
    }
}

TEST_F(LegacyRegularExpressionTest, InvalidPatternAndRangeErrors)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"("
                                                                               options:0
                                                                                 error:&error];
        EXPECT_TRUE(regex == nil);
        ASSERT_TRUE(error != nil);
        EXPECT_TRUE([[error domain] isEqualToString:NSCocoaErrorDomain]);
        EXPECT_EQ(2048, [error code]);

        regex = [NSRegularExpression regularExpressionWithPattern:@"a" options:0 error:&error];
        ASSERT_TRUE(regex != nil);
        BOOL didThrow = NO;
        @try
        {
            [regex matchesInString:@"abc" options:0 range:NSMakeRange(4, 1)];
        }
        @catch (NSException*)
        {
            didThrow = YES;
        }
        EXPECT_TRUE(didThrow);
    }
}

TEST_F(LegacyRegularExpressionTest, UnicodeMatching)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"\\p{L}+"
                                                                               options:0
                                                                                 error:&error];
        ASSERT_TRUE(regex != nil);

        NSString* string = @"åäö 123 café";
        NSArray* matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
        ASSERT_EQ(2U, [matches count]);
        EXPECT_TRUE([[string substringWithRange:[[matches objectAtIndex:0] range]] isEqualToString:@"åäö"]);
        EXPECT_TRUE([[string substringWithRange:[[matches objectAtIndex:1] range]] isEqualToString:@"café"]);
    }
}

TEST_F(LegacyRegularExpressionTest, DataDetectorLinks)
{
    @autoreleasepool
    {
        NSError* error = nil;
        NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
        ASSERT_TRUE(detector != nil);
        EXPECT_TRUE(error == nil);

        NSString* string = @"see https://example.com/a";
        NSArray* matches = [detector matchesInString:string options:0 range:NSMakeRange(0, [string length])];
        ASSERT_EQ(1U, [matches count]);
        NSTextCheckingResult* result = [matches objectAtIndex:0];
        EXPECT_TRUE(NSEqualRanges(NSMakeRange(4, 21), [result range]));
        EXPECT_TRUE([[[result URL] absoluteString] isEqualToString:@"https://example.com/a"]);
    }
}
