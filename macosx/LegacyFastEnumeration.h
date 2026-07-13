// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#import "LegacyFoundationTypes.h"

#if TR_MACOS_SDK_BEFORE_10_5

typedef struct
{
    unsigned long state;
    __unsafe_unretained id* itemsPtr;
    unsigned long* mutationsPtr;
    unsigned long extra[5];
} NSFastEnumerationState;

@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state
                                  objects:(__unsafe_unretained id*)stackBuffer
                                    count:(NSUInteger)length;
@end

#endif

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

@interface NSArray (TRLegacyFastEnumeration) <NSFastEnumeration>
@end

@interface NSDictionary (TRLegacyFastEnumeration) <NSFastEnumeration>
@end

@interface NSEnumerator (TRLegacyFastEnumeration) <NSFastEnumeration>
@end

#endif
