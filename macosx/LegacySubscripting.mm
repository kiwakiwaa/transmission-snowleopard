// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_8

@implementation NSArray (TRObjectSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
    return [self objectAtIndex:idx];
}

@end

@implementation NSMutableArray (TRObjectSubscripting)

- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx
{
    [self replaceObjectAtIndex:idx withObject:obj];
}

@end

@implementation NSDictionary (TRObjectSubscripting)

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

@end

@implementation NSMutableDictionary (TRObjectSubscripting)

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key
{
    if (obj != nil)
    {
        [self setObject:obj forKey:key];
    }
    else
    {
        [self removeObjectForKey:key];
    }
}

@end

#endif
