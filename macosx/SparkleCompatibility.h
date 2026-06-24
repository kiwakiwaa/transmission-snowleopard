// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

@class SUUpdater;

@protocol SUVersionComparison<NSObject>
- (NSComparisonResult)compareVersion:(NSString*)versionA toVersion:(NSString*)versionB;
@end

@protocol SUUpdaterDelegate<NSObject>
@optional
- (void)updaterWillRelaunchApplication:(SUUpdater*)updater;
- (id<SUVersionComparison>)versionComparatorForUpdater:(SUUpdater*)updater;
@end

@interface SUUpdater : NSObject
@property(nonatomic, assign) id<SUUpdaterDelegate> delegate;
+ (SUUpdater*)sharedUpdater;
- (void)checkForUpdates:(id)sender;
@end
