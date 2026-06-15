// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#ifndef NS_ENUM
#if defined(__cplusplus) && (__has_feature(objc_fixed_enum) || __cplusplus >= 201103L)
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#else
#define NS_ENUM(_type, _name) _type _name; enum
#endif
#endif

#ifndef NS_OPTIONS
#if defined(__cplusplus) && (__has_feature(objc_fixed_enum) || __cplusplus >= 201103L)
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#else
#define NS_OPTIONS(_type, _name) _type _name; enum
#endif
#endif
