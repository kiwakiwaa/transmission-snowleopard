// This file Copyright © Mnemosyne LLC.
// It may be used under GPLv2 (SPDX: GPL-2.0-only), GPLv3 (SPDX: GPL-3.0-only),
// or any future license endorsed by Mnemosyne LLC.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <string>
#include <string_view>

#include "libtransmission/string-utils.h"

// macOS implementation of tr_strv_to_utf8_string() that autodetects the encoding.
// This replaces the generic implementation of the function in utils.cc.

static NSString* TRStringByDetectingEncoding(std::string_view sv)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 101000
    NSString* convertedString = nil;
    NSStringEncoding const stringEncoding = [NSString
        stringEncodingForData:[NSData dataWithBytes:std::data(sv) length:std::size(sv)]
              encodingOptions:@{
                  NSStringEncodingDetectionAllowLossyKey : @NO,
                  NSStringEncodingDetectionLikelyLanguageKey : NSLocale.currentLocale.languageCode
              }
              convertedString:&convertedString
          usedLossyConversion:nil];

    if (stringEncoding != 0 && convertedString != nil && convertedString.UTF8String != nullptr)
    {
        return convertedString;
    }

    return nil;
#else
    NSStringEncoding const encodings[] = {
        NSWindowsCP1252StringEncoding,  NSISOLatin1StringEncoding,         NSMacOSRomanStringEncoding,
        NSWindowsCP1250StringEncoding,  NSWindowsCP1251StringEncoding,     NSWindowsCP1253StringEncoding,
        NSWindowsCP1254StringEncoding,  NSISOLatin2StringEncoding,         NSShiftJISStringEncoding,
        NSJapaneseEUCStringEncoding,    NSISO2022JPStringEncoding,         NSUTF16StringEncoding,
        NSUTF16BigEndianStringEncoding, NSUTF16LittleEndianStringEncoding,
    };

    for (auto const encoding : encodings)
    {
        NSString* const convertedString = [[NSString alloc] initWithBytes:std::data(sv) length:std::size(sv) encoding:encoding];
        if (convertedString != nil && convertedString.UTF8String != nullptr)
        {
            return convertedString;
        }
    }

    return nil;
#endif
}

std::string tr_strv_to_utf8_string(std::string_view sv)
{
    // local pool for non-app tools like transmission-daemon, transmission-remote, transmission-create, ...
    @autoreleasepool
    {
        // UTF-8 encoding
        NSString* const utf8 = [[NSString alloc] initWithBytes:std::data(sv) length:std::size(sv) encoding:NSUTF8StringEncoding];
        if (utf8 != nil && utf8.UTF8String != nullptr)
        {
            return tr_strv_to_utf8_string(utf8);
        }

        NSString* const convertedString = TRStringByDetectingEncoding(sv);
        if (convertedString != nil)
        {
            return tr_strv_to_utf8_string(convertedString);
        }

        // invalid encoding
        return tr_strv_replace_invalid(sv);
    }
}

std::string tr_strv_to_utf8_string(NSString* str)
{
    return std::string{ str.UTF8String };
}

NSString* tr_strv_to_utf8_nsstring(std::string_view const sv)
{
    NSString* str = [[NSString alloc] initWithBytes:std::data(sv) length:std::size(sv) encoding:NSUTF8StringEncoding];
    return str ?: @"";
}

NSString* tr_strv_to_utf8_nsstring(std::string_view const sv, NSString* key, NSString* comment)
{
    NSString* str = [[NSString alloc] initWithBytes:std::data(sv) length:std::size(sv) encoding:NSUTF8StringEncoding];
    return str ?: NSLocalizedString(key, comment);
}
