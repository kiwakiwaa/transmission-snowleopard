// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#ifndef __has_include
#define __has_include(x) 0
#endif

#if __has_include(<UserNotifications/UserNotifications.h>)
#define TR_HAS_USER_NOTIFICATIONS 1
#else
#define TR_HAS_USER_NOTIFICATIONS 0
#endif

#if !TR_HAS_USER_NOTIFICATIONS

@class SystemNotificationController;

@protocol SystemNotificationControllerDelegate<NSObject>

- (void)systemNotificationController:(SystemNotificationController*)controller
    didActivateDefaultActionWithUserInfo:(NSDictionary*)userInfo;
- (void)systemNotificationController:(SystemNotificationController*)controller
    didActivateShowActionWithUserInfo:(NSDictionary*)userInfo;

@end

@interface SystemNotificationController : NSObject

@property(nonatomic, TR_OBJC_WEAK) id<SystemNotificationControllerDelegate> delegate;

- (void)configureUserNotifications;
- (void)handleLaunchNotificationFromApplicationNotification:(NSNotification*)notification;

- (void)deliverNotificationWithIdentifier:(NSString*)identifier
                                    title:(NSString*)title
                                     body:(NSString*)body
                                 userInfo:(NSDictionary*)userInfo
                            hasShowAction:(BOOL)hasShowAction;

@end

#endif
