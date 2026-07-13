// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyFastEnumeration.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

#include <libarc_support/arc_runtime.h>

#include <stdint.h>

namespace
{

// Tiger's public collection APIs provide traversal but no mutation counter.
// Transmission does not mutate these collections while traversing them; matching Snow's mutation exception
// would require private Foundation state or invasive mutator interception.
void PrepareState(NSFastEnumerationState* state, __unsafe_unretained id* stackBuffer)
{
    if (state->state == 0)
    {
        state->mutationsPtr = &state->extra[1];
    }

    state->itemsPtr = stackBuffer;
}

NSUInteger Enumerate(NSEnumerator* enumerator, NSFastEnumerationState* state, __unsafe_unretained id* stackBuffer,
    NSUInteger length)
{
    PrepareState(state, stackBuffer);
    NSUInteger count = 0;
    while (count < length)
    {
        id const object = [enumerator nextObject];
        if (object == nil)
        {
            break;
        }

        stackBuffer[count++] = object;
    }

    state->state += count;
    return count;
}

} // namespace

@implementation NSArray (TRLegacyFastEnumeration)

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state
                                  objects:(__unsafe_unretained id*)stackBuffer
                                    count:(NSUInteger)length
{
    PrepareState(state, stackBuffer);
    NSUInteger count = 0;
    NSUInteger const total = self.count;
    while (count < length && state->state + count < total)
    {
        stackBuffer[count] = [self objectAtIndex:state->state + count];
        ++count;
    }

    state->state += count;
    return count;
}

@end

@implementation NSDictionary (TRLegacyFastEnumeration)

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state
                                  objects:(__unsafe_unretained id*)stackBuffer
                                    count:(NSUInteger)length
{
    __unsafe_unretained NSEnumerator* enumerator = nil;
    if (state->state == 0)
    {
        // Fast enumeration has no cleanup callback after an early break. Keep the +0 enumerator alive through
        // the surrounding pool instead of retaining state that cannot always be released.
        enumerator = self.keyEnumerator;
        objc_retainAutorelease(enumerator);
        state->extra[0] = static_cast<unsigned long>(reinterpret_cast<uintptr_t>((__bridge void*)enumerator));
    }
    else
    {
        enumerator = (__bridge NSEnumerator*)reinterpret_cast<void*>(static_cast<uintptr_t>(state->extra[0]));
    }

    return Enumerate(enumerator, state, stackBuffer, length);
}

@end

@implementation NSEnumerator (TRLegacyFastEnumeration)

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state
                                  objects:(__unsafe_unretained id*)stackBuffer
                                    count:(NSUInteger)length
{
    return Enumerate(self, state, stackBuffer, length);
}

@end

#endif
