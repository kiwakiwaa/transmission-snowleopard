// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyArchiving.h"
#import <AppKit/AppKit.h>

#include <algorithm>
#include <cmath>
#include <limits>

#include <libtransmission/macos-version.h>

NSData* TRArchivedDataForObject(id object)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    return [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:nil];
#else
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#endif
}

id TRUnarchiveObjectFromData(NSData* data, NSSet* allowedClasses)
{
    if (data == nil)
    {
        return nil;
    }

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    return [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses fromData:data error:nil];
#else
    if ([allowedClasses containsObject:NSIndexSet.class] || [allowedClasses containsObject:NSMutableIndexSet.class])
    {
        return TRReadArchivedIndexSet(data);
    }
    return nil;
#endif
}

static bool TRReadArchiveUnsigned(NSData* data, NSUInteger* offset, NSUInteger* result)
{
    auto const* bytes = static_cast<unsigned char const*>(data.bytes);
    NSUInteger value = 0;
    for (unsigned shift = 0; shift < std::numeric_limits<NSUInteger>::digits && *offset < data.length; shift += 7)
    {
        unsigned char byte = bytes[(*offset)++];
        NSUInteger digit = byte & 0x7f;
        if (digit > (std::numeric_limits<NSUInteger>::max() >> shift))
        {
            return false;
        }
        value |= digit << shift;
        if ((byte & 0x80) == 0)
        {
            *result = value;
            return true;
        }
    }
    return false;
}

// Read the archive as data before constructing any objects. Older Foundation
// ignores secure-coding allowlists, so it must never instantiate archived classes.
static id TRReadGroupArchiveValue(id reference, NSArray* objects, NSUInteger depth, NSUInteger* budget)
{
    if (depth > 32 || *budget == 0)
    {
        return nil;
    }
    --*budget;

    id value = reference;
    if ([reference isKindOfClass:NSDictionary.class] && [reference count] == 1 && reference[@"TRArchiveUID"])
    {
        id index = reference[@"TRArchiveUID"];
        if (![index isKindOfClass:NSNumber.class] || [index longLongValue] <= 0 || [index unsignedLongLongValue] >= objects.count)
        {
            return nil;
        }
        value = objects[[index unsignedIntegerValue]];
    }
    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSData.class])
    {
        return value;
    }
    if ([value isKindOfClass:NSArray.class])
    {
        NSMutableArray* result = [NSMutableArray array];
        for (id child in value)
        {
            id decoded = TRReadGroupArchiveValue(child, objects, depth + 1, budget);
            if (!decoded)
            {
                return nil;
            }
            [result addObject:decoded];
        }
        return result;
    }
    if (![value isKindOfClass:NSDictionary.class])
    {
        return nil;
    }

    id classReference = value[@"$class"];
    id classIndex = [classReference isKindOfClass:NSDictionary.class] ? classReference[@"TRArchiveUID"] : nil;
    if (![classIndex isKindOfClass:NSNumber.class] || [classIndex longLongValue] < 0 ||
        [classIndex unsignedLongLongValue] >= objects.count)
    {
        return nil;
    }
    id descriptor = objects[[classIndex unsignedIntegerValue]];
    NSString* className = [descriptor isKindOfClass:NSDictionary.class] ? descriptor[@"$classname"] : nil;
    if (![className isKindOfClass:NSString.class])
    {
        return nil;
    }
    if ([className isEqualToString:@"NSArray"] || [className isEqualToString:@"NSMutableArray"])
    {
        return TRReadGroupArchiveValue(value[@"NS.objects"], objects, depth + 1, budget);
    }
    if ([className isEqualToString:@"NSDictionary"] || [className isEqualToString:@"NSMutableDictionary"])
    {
        NSArray* keys = value[@"NS.keys"];
        NSArray* values = value[@"NS.objects"];
        if (![keys isKindOfClass:NSArray.class] || ![values isKindOfClass:NSArray.class] || keys.count != values.count)
        {
            return nil;
        }
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < keys.count; ++i)
        {
            id key = TRReadGroupArchiveValue(keys[i], objects, depth + 1, budget);
            if (![key isKindOfClass:NSString.class])
            {
                return nil;
            }
            id decoded = TRReadGroupArchiveValue(values[i], objects, depth + 1, budget);
            if (decoded)
            {
                result[key] = decoded;
            }
            else if ([key isEqualToString:@"AutoGroupRules"])
            {
                result[key] = [NSNull null];
            }
        }
        return result;
    }
    if ([className isEqualToString:@"NSString"] || [className isEqualToString:@"NSMutableString"])
    {
        id string = value[@"NS.string"];
        return [string isKindOfClass:NSString.class] ? string : nil;
    }
    if ([className isEqualToString:@"NSData"] || [className isEqualToString:@"NSMutableData"])
    {
        id data = value[@"NS.data"];
        return [data isKindOfClass:NSData.class] ? data : nil;
    }
    if ([className isEqualToString:@"NSIndexSet"] || [className isEqualToString:@"NSMutableIndexSet"])
    {
        NSNumber* count = value[@"NSRangeCount"];
        if (![count isKindOfClass:NSNumber.class] || count.longLongValue < 0 || count.unsignedLongLongValue > 4096)
        {
            return nil;
        }
        NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
        NSData* data = count.unsignedIntegerValue > 1 ? TRReadGroupArchiveValue(value[@"NSRangeData"], objects, depth + 1, budget) : nil;
        if (count.unsignedIntegerValue > 1 && ![data isKindOfClass:NSData.class])
        {
            return nil;
        }
        NSUInteger offset = 0;
        NSUInteger total = 0;
        for (NSUInteger i = 0; i < count.unsignedIntegerValue; ++i)
        {
            NSUInteger location, length;
            if (count.unsignedIntegerValue == 1)
            {
                id first = value[@"NSLocation"];
                id size = value[@"NSLength"];
                if (![first isKindOfClass:NSNumber.class] || ![size isKindOfClass:NSNumber.class] || [first longLongValue] < 0 ||
                    [size longLongValue] < 0 || [first unsignedLongLongValue] >= NSNotFound || [size unsignedLongLongValue] >= NSNotFound)
                {
                    return nil;
                }
                location = [first unsignedIntegerValue];
                length = [size unsignedIntegerValue];
            }
            else if (!TRReadArchiveUnsigned(data, &offset, &location) || !TRReadArchiveUnsigned(data, &offset, &length))
            {
                return nil;
            }
            if (length > 65536 - total || location >= NSNotFound || length > NSNotFound - location)
            {
                return nil;
            }
            total += length;
            [indexes addIndexesInRange:NSMakeRange(location, length)];
        }
        return offset == data.length ? indexes : nil;
    }
    if ([className isEqualToString:@"NSColor"])
    {
        id catalog = TRReadGroupArchiveValue(value[@"NSCatalogName"], objects, depth + 1, budget);
        id name = TRReadGroupArchiveValue(value[@"NSColorName"], objects, depth + 1, budget);
        if (([catalog isEqual:@"System"] || [catalog isEqual:@"SystemColors"]) && [name isKindOfClass:NSString.class])
        {
            NSColor* colour = [NSColor colorWithCatalogName:catalog colorName:name];
            if (colour)
            {
                return colour;
            }
        }
        NSData* components = value[@"NSRGB"] ?: value[@"NSWhite"];
        if (![components isKindOfClass:NSData.class])
        {
            return [NSColor grayColor];
        }
        NSString* text = [[NSString alloc] initWithData:components encoding:NSASCIIStringEncoding];
        if (!text)
        {
            return [NSColor grayColor];
        }
        NSScanner* scanner = [NSScanner scannerWithString:text];
        float red, green, blue, alpha = 1.0;
        if (![scanner scanFloat:&red])
        {
            return [NSColor grayColor];
        }
        if (value[@"NSRGB"])
        {
            if (![scanner scanFloat:&green] || ![scanner scanFloat:&blue])
            {
                return [NSColor grayColor];
            }
        }
        else
        {
            green = blue = red;
        }
        [scanner scanFloat:&alpha];
        if (!std::isfinite(red) || !std::isfinite(green) || !std::isfinite(blue) || !std::isfinite(alpha))
        {
            return [NSColor grayColor];
        }
        return [NSColor colorWithCalibratedRed:std::clamp(red, 0.0f, 1.0f) green:std::clamp(green, 0.0f, 1.0f)
                                          blue:std::clamp(blue, 0.0f, 1.0f)
                                         alpha:std::clamp(alpha, 0.0f, 1.0f)];
    }

    // Predicate records remain inert dictionaries. Only the rule validator may
    // turn their supported fields into freshly constructed predicates.
    NSSet* recordClasses = [NSSet setWithObjects:@"NSComparisonPredicate",
                                                 @"NSCompoundPredicate",
                                                 @"NSKeyPathExpression",
                                                 @"NSKeyPathSpecifierExpression",
                                                 @"NSConstantValueExpression",
                                                 @"NSSelfExpression",
                                                 @"NSPredicateOperator",
                                                 @"NSInPredicateOperator",
                                                 @"NSEqualityPredicateOperator",
                                                 @"NSSubstringPredicateOperator",
                                                 @"NSMatchingPredicateOperator",
                                                 @"TRLegacyContainsPredicate",
                                                 nil];
    if (![recordClasses containsObject:className])
    {
        return nil;
    }
    NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObject:className forKey:@"TRArchivedClass"];
    for (NSString* key in value)
    {
        if ([key isEqualToString:@"$class"])
        {
            continue;
        }
        id decoded = TRReadGroupArchiveValue(value[key], objects, depth + 1, budget);
        if (decoded)
        {
            result[key] = decoded;
        }
    }
    return result;
}

static id TRReadPreferencesArchive(NSData* data)
{
    if (![data isKindOfClass:NSData.class] || data.length > 8 * 1024 * 1024)
    {
        return nil;
    }
    @try
    {
        NSPropertyListFormat format;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        id archive = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable
                                                                format:&format
                                                      errorDescription:NULL];
        // Rename UID dictionary keys before parsing the XML again, otherwise
        // Foundation turns them back into opaque Core Foundation UID objects.
        NSData* xml = [NSPropertyListSerialization dataFromPropertyList:archive format:NSPropertyListXMLFormat_v1_0
                                                       errorDescription:NULL];
        NSString* text = xml ? [[NSString alloc] initWithData:xml encoding:NSUTF8StringEncoding] : nil;
        text = [text stringByReplacingOccurrencesOfString:@"<key>CF$UID</key>" withString:@"<key>TRArchiveUID</key>"];
        xml = [text dataUsingEncoding:NSUTF8StringEncoding];
        archive = xml ? [NSPropertyListSerialization propertyListFromData:xml mutabilityOption:NSPropertyListImmutable
                                                                   format:&format
                                                         errorDescription:NULL] :
                        nil;
#pragma clang diagnostic pop
        if (![archive isKindOfClass:NSDictionary.class] || ![archive[@"$archiver"] isEqual:@"NSKeyedArchiver"])
        {
            return nil;
        }
        NSArray* objects = archive[@"$objects"];
        NSDictionary* top = archive[@"$top"];
        if (![objects isKindOfClass:NSArray.class] || objects.count > 65536 || ![top isKindOfClass:NSDictionary.class])
        {
            return nil;
        }
        NSUInteger budget = 65536;
        id result = TRReadGroupArchiveValue(top[@"root"], objects, 0, &budget);
        return budget > 0 ? result : nil;
    }
    @catch (NSException* exception)
    {
        return nil;
    }
}

id TRReadGroupArchive(NSData* data)
{
    id value = TRReadPreferencesArchive(data);
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

NSIndexSet* TRReadArchivedIndexSet(NSData* data)
{
    id value = TRReadPreferencesArchive(data);
    return [value isKindOfClass:NSIndexSet.class] ? value : nil;
}
