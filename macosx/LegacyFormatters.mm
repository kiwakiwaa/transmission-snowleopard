// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyFormatters.h"
#import "CocoaCompatibility.h"

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

#import "LegacyAssociatedObjects.h"

#import <objc/objc-class.h>
#import <objc/objc-runtime.h>

namespace
{

char TRDoesRelativeDateFormattingKey;

struct TRRelativeDateNames
{
    char const* locale;
    char const* names[7]; // Day offsets -3 through +3. NULL means use the absolute date.
};

// These are the relative day names used by the Mac OS X 10.6 ICU data for
// Transmission's supported locales. Some locales intentionally have gaps.
TRRelativeDateNames const RelativeDateNames[] = {
    { "da", { "for tre dage siden", "i forgårs", "i går", "i dag", "i morgen", "i overmorgen", "om tre dage" } },
    { "de", { "Vor drei Tagen", "Vorgestern", "Gestern", "Heute", "Morgen", "Übermorgen", "In drei Tagen" } },
    { "en", { NULL, NULL, "Yesterday", "Today", "Tomorrow", NULL, NULL } },
    { "es", { NULL, "antes de ayer", "ayer", "hoy", "mañana", "pasado mañana", NULL } },
    { "eu", { NULL, NULL, "Yesterday", "Today", "Tomorrow", NULL, NULL } },
    { "fr", { "avant-avant-hier", "avant-hier", "hier", "aujourd’hui", "demain", "après-demain", "après-après-demain" } },
    { "he", { "לפני שלושה ימים", "שלשום", "אתמול", "היום", "מחר", "מחרתיים", "בעוד שלושה ימים" } },
    { "hu", { "három nappal ezelőtt", "tegnapelőtt", "tegnap", "ma", "holnap", "holnapután", "három nap múlva" } },
    { "it", { "tre giorni fa", "l'altro ieri", "ieri", "oggi", "domani", "dopodomani", "tra tre giorni" } },
    { "ja", { NULL, "一昨日", "昨日", "今日", "明日", "明後日", NULL } },
    { "nl", { "Drie dagen geleden", "Eergisteren", "Gisteren", "Vandaag", "Morgen", "Overmorgen", "Over drie dagen" } },
    { "pl", { "Trzy dni temu", "Przedwczoraj", "Wczoraj", "Dzisiaj", "Jutro", "Pojutrze", "Za trzy dni" } },
    { "pt_BR", { "Três dias atrás", "Antes de ontem", "Ontem", "Hoje", "Amanhã", "Depois de amanhã", "Três dias a partir de hoje" } },
    { "pt_PT", { "Trás-anteontem", "Anteontem", NULL, NULL, NULL, NULL, "Em três dias" } },
    { "ru", { NULL, "Позавчера", "Вчера", "Сегодня", "Завтра", "Послезавтра", NULL } },
    { "sv", { NULL, "i förrgår", "igår", "idag", "imorgon", "i övermorgon", NULL } },
    { "tr", { "Üç gün önce", "Evvelsi gün", "Dün", "Bugün", "Yarın", "Yarından sonraki gün", "Üç gün sonra" } },
    { "uk", { NULL, "Позавчора", "Вчора", "Сьогодні", "Завтра", "Післязавтра", NULL } },
    { "zh_CN", { NULL, "前天", "昨天", "今天", "明天", "后天", NULL } },
    { "zh_TW", { "大前天", NULL, NULL, NULL, NULL, "後天", "大後天" } },
};

NSString* TRRelativeDateLocaleIdentifier(NSLocale* locale)
{
    NSString* identifier = [locale localeIdentifier];
    if (identifier == nil)
    {
        identifier = [[NSLocale currentLocale] localeIdentifier];
    }

    identifier = [[identifier componentsSeparatedByString:@"@"] objectAtIndex:0];
    identifier = [[identifier componentsSeparatedByString:@"-"] componentsJoinedByString:@"_"];
    NSArray* components = [identifier componentsSeparatedByString:@"_"];
    NSString* language = [[components objectAtIndex:0] lowercaseString];

    if ([language isEqualToString:@"iw"])
    {
        return @"he";
    }
    if ([language isEqualToString:@"pt"])
    {
        for (NSString* component in components)
        {
            if ([[component uppercaseString] isEqualToString:@"BR"])
            {
                return @"pt_BR";
            }
        }
        return @"pt_PT";
    }
    if ([language isEqualToString:@"zh"])
    {
        for (NSString* component in components)
        {
            NSString* normalized = [component lowercaseString];
            if ([normalized isEqualToString:@"tw"] || [normalized isEqualToString:@"hant"])
            {
                return @"zh_TW";
            }
        }
        return @"zh_CN";
    }
    return language;
}

NSString* TRRelativeDateName(NSString* localeIdentifier, NSInteger dayOffset)
{
    if (dayOffset < -3 || dayOffset > 3)
    {
        return nil;
    }

    for (NSUInteger i = 0; i < sizeof(RelativeDateNames) / sizeof(RelativeDateNames[0]); ++i)
    {
        TRRelativeDateNames const& entry = RelativeDateNames[i];
        if ([localeIdentifier isEqualToString:[NSString stringWithUTF8String:entry.locale]])
        {
            char const* name = entry.names[dayOffset + 3];
            return name != NULL ? [NSString stringWithUTF8String:name] : nil;
        }
    }
    return nil;
}

NSString* TRSnowLeopardShortTimeString(NSDateFormatter* formatter, NSDate* date, NSString* localeIdentifier)
{
    NSDateFormatter* timeOnlyFormatter = [[NSDateFormatter alloc] init];
    [timeOnlyFormatter setFormatterBehavior:[formatter formatterBehavior]];
    [timeOnlyFormatter setLocale:[formatter locale]];
    [timeOnlyFormatter setCalendar:[formatter calendar]];
    [timeOnlyFormatter setTimeZone:[formatter timeZone]];
    [timeOnlyFormatter setDateStyle:NSDateFormatterNoStyle];
    [timeOnlyFormatter setTimeStyle:NSDateFormatterShortStyle];

    NSMutableString* time = [[timeOnlyFormatter stringFromDate:date] mutableCopy];
    if ([localeIdentifier isEqualToString:@"it"])
    {
        // Tiger's ICU uses a colon here; Snow Leopard's short Italian time uses a period.
        NSRange separator = [time rangeOfString:@":"];
        if (separator.location != NSNotFound)
        {
            [time replaceCharactersInRange:separator withString:@"."];
        }
    }
    else if ([localeIdentifier isEqualToString:@"zh_TW"])
    {
        // Tiger inserts a space after the day period; Snow Leopard does not.
        NSRange spacing = [time rangeOfString:@" "];
        if (spacing.location != NSNotFound)
        {
            [time deleteCharactersInRange:spacing];
        }
    }
    return time;
}

NSInteger TRRelativeDateDayOffset(NSDateFormatter* formatter, NSDate* date)
{
    NSCalendar* calendar = [[formatter calendar] copy];
    if (calendar == nil)
    {
        calendar = [[NSCalendar currentCalendar] copy];
    }
    if ([formatter timeZone] != nil)
    {
        [calendar setTimeZone:[formatter timeZone]];
    }

    NSUInteger const units = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
    NSDateComponents* todayComponents = [calendar components:units fromDate:[NSDate date]];
    NSDateComponents* dateComponents = [calendar components:units fromDate:date];
    [todayComponents setHour:12];
    [dateComponents setHour:12];

    NSDate* today = [calendar dateFromComponents:todayComponents];
    NSDate* target = [calendar dateFromComponents:dateComponents];
    if (today == nil || target == nil)
    {
        return NSIntegerMax;
    }
    return [[calendar components:NSDayCalendarUnit fromDate:today toDate:target options:0] day];
}

NSString* TRRelativeDateString(NSDateFormatter* formatter, NSDate* date, NSString* absoluteString)
{
    if (![formatter doesRelativeDateFormatting] || [formatter dateStyle] == NSDateFormatterNoStyle)
    {
        return absoluteString;
    }

    NSString* localeIdentifier = TRRelativeDateLocaleIdentifier([formatter locale]);
    NSString* relativeName = TRRelativeDateName(localeIdentifier, TRRelativeDateDayOffset(formatter, date));
    if (relativeName == nil)
    {
        return absoluteString;
    }

    if ([formatter timeStyle] == NSDateFormatterNoStyle)
    {
        return relativeName;
    }
    if ([formatter timeStyle] != NSDateFormatterShortStyle)
    {
        return absoluteString; // Transmission has no relative formatter using another time style.
    }

    NSString* time = TRSnowLeopardShortTimeString(formatter, date, localeIdentifier);
    // Every supported Snow Leopard relative-date + short-time pattern places the relative day first with one separating space.
    return time != nil ? [NSString stringWithFormat:@"%@ %@", relativeName, time] : absoluteString;
}

using TRStringForObjectValueImplementation = NSString* (*)(id, SEL, id);
TRStringForObjectValueImplementation OriginalStringForObjectValue = NULL;
TRStringForObjectValueImplementation OriginalStringFromDate = NULL;

NSString* TRStringForObjectValue(NSDateFormatter* formatter, SEL selector, id object)
{
    NSString* absoluteString = OriginalStringForObjectValue(formatter, selector, object);
    if (![object isKindOfClass:[NSDate class]] || absoluteString == nil)
    {
        return absoluteString;
    }
    return TRRelativeDateString(formatter, object, absoluteString);
}

NSString* TRStringFromDate(NSDateFormatter* formatter, SEL selector, NSDate* date)
{
    NSString* absoluteString = OriginalStringFromDate(formatter, selector, date);
    return date != nil && absoluteString != nil ? TRRelativeDateString(formatter, date, absoluteString) : absoluteString;
}

} // namespace

@implementation NSDateFormatter (TRRelativeDateFormatting)

+ (void)load
{
    Method method = class_getInstanceMethod(self, @selector(stringForObjectValue:));
    if (method != NULL)
    {
        OriginalStringForObjectValue = (TRStringForObjectValueImplementation)method->method_imp;
        method->method_imp = (IMP)TRStringForObjectValue;
    }

    method = class_getInstanceMethod(self, @selector(stringFromDate:));
    if (method != NULL)
    {
        OriginalStringFromDate = (TRStringForObjectValueImplementation)method->method_imp;
        method->method_imp = (IMP)TRStringFromDate;
    }
}

- (BOOL)doesRelativeDateFormatting
{
    if ([self formatterBehavior] != NSDateFormatterBehavior10_4)
    {
        return NO;
    }
    return [TRLegacyGetAssociatedObject(self, &TRDoesRelativeDateFormattingKey) boolValue];
}

- (void)setDoesRelativeDateFormatting:(BOOL)doesRelativeDateFormatting
{
    if ([self formatterBehavior] != NSDateFormatterBehavior10_4)
    {
        return;
    }
    NSNumber* value = doesRelativeDateFormatting ? [NSNumber numberWithBool:YES] : nil;
    TRLegacySetAssociatedObject(self, &TRDoesRelativeDateFormattingKey, value, TRLegacyAssociationRetainNonatomic);
}

@end

#endif

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
