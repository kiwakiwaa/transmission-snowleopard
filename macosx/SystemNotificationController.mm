// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#ifndef __has_include
#define __has_include(x) 0
#endif

#if __has_include(<UserNotifications/UserNotifications.h>)
#define TR_HAS_USER_NOTIFICATIONS 1
#else
#define TR_HAS_USER_NOTIFICATIONS 0
#endif

#if !TR_HAS_USER_NOTIFICATIONS

#if __has_feature(modules)
@import AppKit;
@import Foundation;
#else
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#endif

#if __has_include(<Foundation/NSUserNotification.h>)
#define TR_HAS_LEGACY_USER_NOTIFICATIONS 1
#import <Foundation/NSUserNotification.h>
#else
#define TR_HAS_LEGACY_USER_NOTIFICATIONS 0
#endif

#import "SystemNotificationController.h"

namespace
{

NSString* const UserInfoHashKey = @"Hash";
NSString* const UserInfoIdentifierKey = @"TransmissionNotificationIdentifier";

} // namespace

#if TR_HAS_LEGACY_USER_NOTIFICATIONS
#define TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_BEGIN \
    _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
#define TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_END _Pragma("clang diagnostic pop")
#else
#define TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_BEGIN
#define TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_END
#endif

#if TR_HAS_LEGACY_USER_NOTIFICATIONS
@interface SystemNotificationController (NSUserNotificationCenterDelegate)<NSUserNotificationCenterDelegate>
@end
#endif

@implementation SystemNotificationController

- (void)configureUserNotifications
{
#if TR_HAS_LEGACY_USER_NOTIFICATIONS
    TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_BEGIN
    NSUserNotificationCenter.defaultUserNotificationCenter.delegate = self;
    TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_END
#endif
}

- (void)handleLaunchNotificationFromApplicationNotification:(NSNotification*)notification
{
#if TR_HAS_LEGACY_USER_NOTIFICATIONS
    TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_BEGIN
    NSUserNotification* launchNotification = notification.userInfo[NSApplicationLaunchUserNotificationKey];
    if (launchNotification)
    {
        [self userNotificationCenter:NSUserNotificationCenter.defaultUserNotificationCenter didActivateNotification:launchNotification];
    }
    TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_END
#endif
}

- (void)deliverNotificationWithIdentifier:(NSString*)identifier
                                    title:(NSString*)title
                                     body:(NSString*)body
                                 userInfo:(NSDictionary*)userInfo
                            hasShowAction:(BOOL)hasShowAction
{
#if TR_HAS_LEGACY_USER_NOTIFICATIONS
    TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_BEGIN
    NSUserNotification* notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = body;
    notification.hasActionButton = hasShowAction;
    if (hasShowAction)
    {
        notification.actionButtonTitle = NSLocalizedString(@"Show", "notification button");
    }
    notification.userInfo = [self legacyUserInfoByAddingIdentifier:identifier toUserInfo:userInfo];

    [self removeDeliveredLegacyNotificationWithIdentifier:identifier];
    [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
    TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_END
#endif
}

#if TR_HAS_LEGACY_USER_NOTIFICATIONS
TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_BEGIN

- (NSDictionary*)legacyUserInfoByAddingIdentifier:(NSString*)identifier toUserInfo:(NSDictionary*)userInfo
{
    NSMutableDictionary* legacyUserInfo = userInfo ? [userInfo mutableCopy] : [NSMutableDictionary dictionary];
    legacyUserInfo[UserInfoIdentifierKey] = identifier;
    return legacyUserInfo;
}

- (void)removeDeliveredLegacyNotificationWithIdentifier:(NSString*)identifier
{
    if (!identifier)
    {
        return;
    }

    for (NSUserNotification* notification in NSUserNotificationCenter.defaultUserNotificationCenter.deliveredNotifications)
    {
        if ([notification.userInfo[UserInfoIdentifierKey] isEqualToString:identifier])
        {
            [NSUserNotificationCenter.defaultUserNotificationCenter removeDeliveredNotification:notification];
        }
    }
}

- (BOOL)legacyNotificationUserInfoCanActivate:(NSDictionary*)userInfo
{
    return [userInfo[UserInfoHashKey] isKindOfClass:NSString.class];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter*)center shouldPresentNotification:(NSUserNotification*)notification
{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter*)center didActivateNotification:(NSUserNotification*)notification
{
    NSDictionary* userInfo = notification.userInfo;
    if (![self legacyNotificationUserInfoCanActivate:userInfo])
    {
        return;
    }

    if (notification.activationType == NSUserNotificationActivationTypeActionButtonClicked)
    {
        [self.delegate systemNotificationController:self didActivateShowActionWithUserInfo:userInfo];
    }
    else if (notification.activationType == NSUserNotificationActivationTypeContentsClicked)
    {
        [self.delegate systemNotificationController:self didActivateDefaultActionWithUserInfo:userInfo];
    }
}

TR_LEGACY_USER_NOTIFICATIONS_IGNORE_DEPRECATIONS_END
#endif

@end

#endif
