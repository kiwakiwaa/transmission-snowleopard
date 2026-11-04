// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

NSData* TRArchivedDataForObject(id object);
id TRUnarchiveObjectFromData(NSData* data, NSSet* allowedClasses);

// Read group preferences without instantiating any archived classes.
id TRReadGroupArchive(NSData* data);

NSIndexSet* TRReadArchivedIndexSet(NSData* data);
