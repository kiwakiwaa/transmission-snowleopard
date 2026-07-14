// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyFormatters.h"
#import "CocoaCompatibility.h"

#include <libtransmission/macos-version.h>

static NSString* TRLegacyTimeRemainingString(NSTimeInterval interval)
{
    NSInteger secondsTotal = MAX(0, (NSInteger)interval);
    NSInteger days = secondsTotal / (60 * 60 * 24);
    secondsTotal %= 60 * 60 * 24;
    NSInteger hours = secondsTotal / (60 * 60);
    secondsTotal %= 60 * 60;
    NSInteger minutes = secondsTotal / 60;
    NSInteger seconds = secondsTotal % 60;

    NSMutableArray* parts = [NSMutableArray arrayWithCapacity:2];
    if (days > 0)
    {
        [parts addObject:[NSString stringWithFormat:@"%ld d", (long)days]];
    }
    if (hours > 0 && parts.count < 2)
    {
        [parts addObject:[NSString stringWithFormat:@"%ld hr", (long)hours]];
    }
    if (minutes > 0 && parts.count < 2)
    {
        [parts addObject:[NSString stringWithFormat:@"%ld min", (long)minutes]];
    }
    if (parts.count == 0)
    {
        [parts addObject:[NSString stringWithFormat:@"%ld sec", (long)seconds]];
    }

    NSString* duration = [parts componentsJoinedByString:@" "];
    return [NSString stringWithFormat:NSLocalizedString(@"%@ remaining", "Torrent -> eta string"), duration];
}

static NSString* TRLegacyStatsDurationString(NSTimeInterval interval)
{
    NSInteger minutes = MAX(0, (NSInteger)(interval / 60.0));
    NSInteger years = minutes / (60 * 24 * 365);
    minutes %= (60 * 24 * 365);
    NSInteger months = minutes / (60 * 24 * 30);
    minutes %= (60 * 24 * 30);
    NSInteger weeks = minutes / (60 * 24 * 7);
    minutes %= (60 * 24 * 7);
    NSInteger days = minutes / (60 * 24);
    minutes %= (60 * 24);
    NSInteger hours = minutes / 60;
    minutes %= 60;

    NSMutableArray* parts = [NSMutableArray arrayWithCapacity:3];
    struct Unit
    {
        NSInteger value;
        NSString* suffix;
    } units[] = { { years, @"y" }, { months, @"mo" }, { weeks, @"w" }, { days, @"d" }, { hours, @"h" }, { minutes, @"m" } };

    for (NSUInteger i = 0; i < sizeof(units) / sizeof(units[0]) && parts.count < 3; ++i)
    {
        if (units[i].value > 0 || parts.count > 0)
        {
            [parts addObject:[NSString stringWithFormat:@"%ld%@", (long)units[i].value, units[i].suffix]];
        }
    }

    if (parts.count == 0)
    {
        [parts addObject:@"0m"];
    }

    return [parts componentsJoinedByString:@" "];
}

static NSString* TRLegacyTrackerCountdownString(NSTimeInterval interval)
{
    NSInteger secondsTotal = MAX(0, (NSInteger)interval);
    NSInteger hours = secondsTotal / (60 * 60);
    secondsTotal %= 60 * 60;
    NSInteger minutes = secondsTotal / 60;
    NSInteger seconds = secondsTotal % 60;

    if (hours > 0)
    {
        return [NSString stringWithFormat:@"%ldh %ldm", (long)hours, (long)minutes];
    }
    if (minutes > 0)
    {
        return [NSString stringWithFormat:@"%ldm %lds", (long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%lds", (long)seconds];
}

static NSString* TRLegacyShortDurationString(NSTimeInterval interval)
{
    NSInteger seconds = MAX(0, (NSInteger)interval);
    NSInteger days = seconds / (60 * 60 * 24);
    seconds %= 60 * 60 * 24;
    NSInteger hours = seconds / (60 * 60);
    seconds %= 60 * 60;
    NSInteger minutes = seconds / 60;
    seconds %= 60;

    NSMutableArray* parts = [NSMutableArray arrayWithCapacity:4];
    if (days > 0)
    {
        [parts addObject:[NSString stringWithFormat:@"%ldd", (long)days]];
    }
    if (hours > 0 || parts.count > 0)
    {
        [parts addObject:[NSString stringWithFormat:@"%ldh", (long)hours]];
    }
    if (minutes > 0 || parts.count > 0)
    {
        [parts addObject:[NSString stringWithFormat:@"%ldm", (long)minutes]];
    }
    [parts addObject:[NSString stringWithFormat:@"%lds", (long)seconds]];

    return [parts componentsJoinedByString:@" "];
}

NSString* TRTimeRemainingString(NSTimeInterval interval)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    static NSDateComponentsFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateComponentsFormatter alloc] init];
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
        formatter.maximumUnitCount = 2;
        formatter.collapsesLargestUnit = YES;
        formatter.includesTimeRemainingPhrase = YES;
    });

    // The duration of months is variable, so keep the old upstream reference-date behavior.
    NSDate* referenceDate = [NSDate date];
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_13 && !TR_MACOS_SDK_BEFORE_10_13
    formatter.referenceDate = referenceDate;
    NSString* string = [formatter stringFromTimeInterval:interval];
#else
    NSString* string = [formatter stringFromDate:referenceDate toDate:TRDateByAddingTimeInterval(referenceDate, interval)];
#endif
    return string ?: TRLegacyTimeRemainingString(interval);
#else
    return TRLegacyTimeRemainingString(interval);
#endif
}

NSString* TRShortDurationString(NSTimeInterval interval)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    static NSDateComponentsFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateComponentsFormatter new];
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
        formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropLeading;
    });

    NSString* string = [formatter stringFromTimeInterval:interval];
    return string ?: TRLegacyShortDurationString(interval);
#else
    return TRLegacyShortDurationString(interval);
#endif
}

NSString* TRStatsDurationString(NSTimeInterval interval)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    static NSDateComponentsFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateComponentsFormatter alloc] init];
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        formatter.maximumUnitCount = 3;
        formatter.allowedUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay |
            NSCalendarUnitHour | NSCalendarUnitMinute;
    });

    NSString* string = [formatter stringFromTimeInterval:interval];
    return string ?: TRLegacyStatsDurationString(interval);
#else
    return TRLegacyStatsDurationString(interval);
#endif
}

NSString* TRTrackerCountdownString(NSTimeInterval interval)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    static NSDateComponentsFormatter* formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateComponentsFormatter alloc] init];
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
        formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropLeading;
        formatter.collapsesLargestUnit = YES;
    });

    NSString* string = [formatter stringFromTimeInterval:interval];
    return string ?: TRLegacyTrackerCountdownString(interval);
#else
    return TRLegacyTrackerCountdownString(interval);
#endif
}
