// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#pragma once

#include <libtransmission/macos-version.h>

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6

#include <stddef.h>

#ifdef __cplusplus
extern "C"
{
#endif

typedef long dispatch_once_t;
typedef void (^dispatch_block_t)(void);

typedef struct TRLegacyDispatchQueue* dispatch_queue_t;
typedef const struct TRLegacyDispatchQueueAttribute* dispatch_queue_attr_t;

#ifndef DISPATCH_QUEUE_SERIAL
#define DISPATCH_QUEUE_SERIAL ((dispatch_queue_attr_t)0)
#endif

void dispatch_once(dispatch_once_t* predicate, __unsafe_unretained dispatch_block_t block);

dispatch_queue_t dispatch_get_main_queue(void);
dispatch_queue_t dispatch_queue_create(char const* label, dispatch_queue_attr_t attr);

void dispatch_async(dispatch_queue_t queue, __unsafe_unretained dispatch_block_t block);

void dispatch_retain(dispatch_queue_t queue);
void dispatch_release(dispatch_queue_t queue);

#ifdef __cplusplus
}
#endif

#else

#include <dispatch/dispatch.h>

#endif
