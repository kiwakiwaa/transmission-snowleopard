// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>
#import "LegacyArchiving.h"

#include <gtest/gtest.h>

static bool groupArchiveDecodedUnexpectedObject = false;

@interface GroupArchiveUnexpectedObject : NSObject<NSSecureCoding>
@end

@implementation GroupArchiveUnexpectedObject
+ (BOOL)supportsSecureCoding
{
    return YES;
}
- (instancetype)initWithCoder:(NSCoder*)coder
{
    groupArchiveDecodedUnexpectedObject = true;
    return [super init];
}
- (void)encodeWithCoder:(NSCoder*)coder
{
}
@end

TEST(GroupArchive, preservesGroupMetadataAndRuleSchema)
{
    @autoreleasepool
    {
        NSDictionary* rule = @{
            @"Type" : @"Comparison",
            @"KeyPath" : @"name",
            @"Operator" : @99,
            @"Modifier" : @0,
            @"Options" : @3,
            @"Value" : @"sample"
        };
        NSDictionary* group = @{
            @"Index" : @3,
            @"Name" : @"One",
            @"Color" : [NSColor colorWithCalibratedRed:0.2 green:0.4 blue:0.6 alpha:1.0],
            @"AnnouncedClientIdentity" : @"transmission-4.0.6",
            @"AnnounceClientVersion" : @"4.0.6",
            @"AutoGroupRulesSchema" : rule,
            @"UsesAutoGroupRules" : @(YES)
        };
        NSArray* decoded = TRReadGroupArchive(TRArchivedDataForObject(@[ group ]));
        ASSERT_EQ(1U, decoded.count);
        NSDictionary* result = decoded[0];
        EXPECT_TRUE([result[@"Name"] isEqual:group[@"Name"]]);
        EXPECT_TRUE([result[@"Index"] isEqual:group[@"Index"]]);
        EXPECT_TRUE([result[@"AnnouncedClientIdentity"] isEqual:group[@"AnnouncedClientIdentity"]]);
        EXPECT_TRUE([result[@"AnnounceClientVersion"] isEqual:group[@"AnnounceClientVersion"]]);
        EXPECT_TRUE([result[@"AutoGroupRulesSchema"] isEqual:rule]);
        NSColor* colour = [result[@"Color"] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        ASSERT_NE(nil, colour);
        EXPECT_NEAR(0.2, colour.redComponent, 0.001);
        EXPECT_NEAR(0.4, colour.greenComponent, 0.001);
        EXPECT_NEAR(0.6, colour.blueComponent, 0.001);
    }
}

TEST(GroupArchive, neverInstantiatesArchivedClasses)
{
    @autoreleasepool
    {
        groupArchiveDecodedUnexpectedObject = false;
        NSDictionary* group = @{@"Index" : @1, @"AutoGroupRules" : [[GroupArchiveUnexpectedObject alloc] init]};
        NSArray* decoded = TRReadGroupArchive(TRArchivedDataForObject(@[ group ]));
        ASSERT_EQ(1U, decoded.count);
        EXPECT_FALSE(groupArchiveDecodedUnexpectedObject);
        EXPECT_TRUE([decoded[0][@"AutoGroupRules"] isKindOfClass:NSNull.class]);
    }
}

TEST(GroupArchive, leavesLegacyPredicatesAsData)
{
    @autoreleasepool
    {
        NSPredicate* predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", @"sample"];
        NSDictionary* group = @{@"Index" : @1, @"AutoGroupRules" : predicate};
        NSArray* decoded = TRReadGroupArchive(TRArchivedDataForObject(@[ group ]));
        ASSERT_EQ(1U, decoded.count);
        id rule = decoded[0][@"AutoGroupRules"];
        EXPECT_FALSE([rule isKindOfClass:NSPredicate.class]);
        ASSERT_TRUE([rule isKindOfClass:NSDictionary.class]);
        EXPECT_TRUE([rule[@"TRArchivedClass"] isEqual:@"NSComparisonPredicate"]);
    }
}

TEST(GroupArchive, rejectsInvalidAndCyclicArchives)
{
    @autoreleasepool
    {
        EXPECT_EQ(nil, TRReadGroupArchive(nil));
        EXPECT_EQ(nil, TRReadGroupArchive([@"invalid" dataUsingEncoding:NSUTF8StringEncoding]));
        NSDictionary* reference = @{@"CF$UID" : @1};
        NSDictionary* archive = @{
            @"$archiver" : @"NSKeyedArchiver",
            @"$top" : @{ @"root" : reference },
            @"$objects" : @[
                @"$null",
                @{ @"$class" : @{ @"CF$UID" : @2 }, @"NS.objects" : @[ reference ] },
                @{ @"$classname" : @"NSArray" }
            ]
        };
        NSData* data = [NSPropertyListSerialization dataWithPropertyList:archive format:NSPropertyListXMLFormat_v1_0 options:0
                                                                   error:NULL];
        EXPECT_EQ(nil, TRReadGroupArchive(data));
    }
}

TEST(GroupArchive, readsIndexSetsWithoutDecodingClasses)
{
    @autoreleasepool
    {
        NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
        for (NSUInteger count : { 0U, 1U, 2U })
        {
            if (count == 1)
            {
                [indexes addIndex:1];
            }
            else if (count == 2)
            {
                [indexes addIndexesInRange:NSMakeRange(200, 1000)];
            }
            NSIndexSet* decoded = TRReadArchivedIndexSet(TRArchivedDataForObject(indexes));
            ASSERT_NE(nil, decoded);
            EXPECT_TRUE([decoded isEqualToIndexSet:indexes]);
        }
        EXPECT_EQ(nil, TRReadArchivedIndexSet(TRArchivedDataForObject(@[ @1 ])));
    }
}
