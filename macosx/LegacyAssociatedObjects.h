// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#import <Foundation/Foundation.h>

typedef enum
{
    TRLegacyAssociationAssign = 0,
    TRLegacyAssociationRetainNonatomic = 1,
    TRLegacyAssociationCopyNonatomic = 3,
} TRLegacyAssociationPolicy;

id TRLegacyGetAssociatedObject(id object, void const* key);
void TRLegacySetAssociatedObject(id object, void const* key, id value, TRLegacyAssociationPolicy policy);
void TRLegacyRemoveAssociatedObjects(id object);
