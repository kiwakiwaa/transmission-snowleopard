// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

@interface LegacyWeakReference : NSObject

- (instancetype)initWithObject:(id)object;

@property(nonatomic, readonly) id object;

@end

#define TR_LEGACY_WEAK_REFERENCE_ACCESSORS(TYPE, GETTER, SETTER, STORAGE) \
    - (TYPE*)GETTER \
    { \
        return STORAGE.object; \
    } \
    - (void)SETTER:(TYPE*)object \
    { \
        STORAGE = [[LegacyWeakReference alloc] initWithObject:object]; \
    }
