// This file Copyright © Mnemosyne LLC.
// It may be used under GPLv2 (SPDX: GPL-2.0-only), GPLv3 (SPDX: GPL-3.0-only),
// or any future license endorsed by Mnemosyne LLC.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <string>
#include <string_view>

#include "libtransmission/macos-version.h"
#include "libtransmission/string-utils.h"

// macOS implementation of tr_strv_to_utf8_string() that autodetects the encoding.
// This replaces the generic implementation of the function in utils.cc.

#if TR_MACOS_SDK_BEFORE_10_6
static NSString* TRStringByConvertingCFEncoding(std::string_view sv, CFStringEncoding encoding)
{
    CFStringRef const convertedString = CFStringCreateWithBytes(
        kCFAllocatorDefault,
        reinterpret_cast<UInt8 const*>(std::data(sv)),
        static_cast<CFIndex>(std::size(sv)),
        encoding,
        true);
    if (convertedString == nullptr)
    {
        return nil;
    }

    NSString* const nsString = (__bridge_transfer NSString*)convertedString;
    return nsString.UTF8String != nullptr ? nsString : nil;
}
#endif

static NSString* TRStringByDetectingEncoding(std::string_view sv)
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_10 && !TR_MACOS_SDK_BEFORE_10_10
    NSString* convertedString = nil;
    NSStringEncoding const stringEncoding = [NSString
        stringEncodingForData:[NSData dataWithBytes:std::data(sv) length:std::size(sv)]
              encodingOptions:@{
                  NSStringEncodingDetectionAllowLossyKey : @NO,
                  NSStringEncodingDetectionLikelyLanguageKey : [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode]
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
        NSJapaneseEUCStringEncoding,    NSISO2022JPStringEncoding,
#if !TR_MACOS_SDK_BEFORE_10_6
        NSUTF16StringEncoding,          NSUTF16BigEndianStringEncoding,    NSUTF16LittleEndianStringEncoding,
#endif
    };

    for (auto const encoding : encodings)
    {
        NSString* const convertedString = [[NSString alloc] initWithBytes:std::data(sv) length:std::size(sv) encoding:encoding];
        if (convertedString != nil && convertedString.UTF8String != nullptr)
        {
            return convertedString;
        }
    }

#if TR_MACOS_SDK_BEFORE_10_6
    CFStringEncoding const cf_encodings[] = {
        kCFStringEncodingUTF16,
        kCFStringEncodingUTF16BE,
        kCFStringEncodingUTF16LE,
    };

    for (auto const encoding : cf_encodings)
    {
        NSString* const convertedString = TRStringByConvertingCFEncoding(sv, encoding);
        if (convertedString != nil)
        {
            return convertedString;
        }
    }
#endif

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
