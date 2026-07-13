// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyDispatch.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_6

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#include <pthread.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

extern "C" void _Block_use_RR(void (*retain)(const void*), void (*release)(const void*));
extern "C" id objc_retain(id value);
extern "C" void objc_release(id value);
extern "C" void* _NSConcreteMallocBlock[];
extern "C" CFRunLoopRef CFRunLoopGetMain(void);

namespace
{

enum : long
{
    TRDispatchOnceNotStarted = 0,
    TRDispatchOnceInProgress = 1,
    TRDispatchOnceDone = 2,
};

pthread_mutex_t gOnceMutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t gOnceCond = PTHREAD_COND_INITIALIZER;
CFRunLoopRef gMainRunLoop = NULL;

pthread_once_t gBlockRuntimeInitOnce = PTHREAD_ONCE_INIT;

enum
{
    TRLegacyBlockHasCopyDispose = 1 << 25,
    TRLegacyBlockIsGlobal = 1 << 28,
};

struct TRLegacyBlockDescriptor
{
    unsigned long reserved;
    unsigned long size;
};

struct TRLegacyBlockCopyDisposeDescriptor
{
    void (*copyHelper)(void* destination, void const* source);
    void (*disposeHelper)(void const* source);
};

struct TRLegacyBlockLayout
{
    void* isa;
    int flags;
    int reserved;
    void* invoke;
    TRLegacyBlockDescriptor* descriptor;
};

struct TRLegacyDispatchBlockNode
{
    void* block;
    TRLegacyDispatchBlockNode* next;
};

enum TRLegacyDispatchQueueKind
{
    TRLegacyDispatchQueueKindMain,
    TRLegacyDispatchQueueKindSerial,
};

} // namespace

struct TRLegacyDispatchQueue
{
    TRLegacyDispatchQueueKind kind;
    char* label;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    TRLegacyDispatchBlockNode* head;
    TRLegacyDispatchBlockNode* tail;
    unsigned int refcount;
    unsigned int pending;
    bool closing;
    bool worker_started;
    CFRunLoopSourceRef run_loop_source;
};

namespace
{

TRLegacyDispatchQueue gMainQueue = {
    TRLegacyDispatchQueueKindMain,
    const_cast<char*>("com.apple.main-thread"),
    PTHREAD_MUTEX_INITIALIZER,
    PTHREAD_COND_INITIALIZER,
    NULL,
    NULL,
    1,
    0,
    false,
    false,
    NULL,
};

pthread_once_t gMainQueueInitOnce = PTHREAD_ONCE_INIT;

void TRLegacyDispatchRetainBlockObject(void const* object)
{
    objc_retain((__bridge id)object);
}

void TRLegacyDispatchReleaseBlockObject(void const* object)
{
    objc_release((__bridge id)object);
}

void TRLegacyDispatchBlockRuntimeInit(void)
{
    _Block_use_RR(TRLegacyDispatchRetainBlockObject, TRLegacyDispatchReleaseBlockObject);
}

TRLegacyBlockCopyDisposeDescriptor* TRLegacyDispatchBlockCopyDisposeDescriptor(TRLegacyBlockLayout const* block)
{
    if ((block->flags & TRLegacyBlockHasCopyDispose) == 0)
    {
        return NULL;
    }

    return reinterpret_cast<TRLegacyBlockCopyDisposeDescriptor*>(block->descriptor + 1);
}

void* TRLegacyDispatchCopyBlock(__unsafe_unretained dispatch_block_t block)
{
    if (block == nil)
    {
        return NULL;
    }

    pthread_once(&gBlockRuntimeInitOnce, TRLegacyDispatchBlockRuntimeInit);

    TRLegacyBlockLayout const* source = reinterpret_cast<TRLegacyBlockLayout const*>((__bridge void const*)block);
    if ((source->flags & TRLegacyBlockIsGlobal) != 0)
    {
        return (void*)(__bridge void const*)block;
    }

    TRLegacyBlockLayout* destination = static_cast<TRLegacyBlockLayout*>(malloc(source->descriptor->size));
    if (destination == NULL)
    {
        return NULL;
    }

    memcpy(destination, source, source->descriptor->size);
    destination->isa = _NSConcreteMallocBlock;

    if (TRLegacyBlockCopyDisposeDescriptor* helpers = TRLegacyDispatchBlockCopyDisposeDescriptor(source))
    {
        helpers->copyHelper(destination, source);
    }

    return destination;
}

void TRLegacyDispatchDisposeCopiedBlock(void* block)
{
    if (block == NULL)
    {
        return;
    }

    TRLegacyBlockLayout const* layout = static_cast<TRLegacyBlockLayout const*>(block);
    if ((layout->flags & TRLegacyBlockIsGlobal) != 0)
    {
        return;
    }

    if (TRLegacyBlockCopyDisposeDescriptor* helpers = TRLegacyDispatchBlockCopyDisposeDescriptor(layout))
    {
        helpers->disposeHelper(layout);
    }

    free(block);
}

void TRLegacyDispatchQueuePushLocked(TRLegacyDispatchQueue* queue, TRLegacyDispatchBlockNode* node)
{
    node->next = NULL;

    if (queue->tail != NULL)
    {
        queue->tail->next = node;
    }
    else
    {
        queue->head = node;
    }

    queue->tail = node;
    ++queue->pending;
}

TRLegacyDispatchBlockNode* TRLegacyDispatchQueuePopLocked(TRLegacyDispatchQueue* queue)
{
    TRLegacyDispatchBlockNode* node = queue->head;
    if (node == NULL)
    {
        return NULL;
    }

    queue->head = node->next;
    if (queue->head == NULL)
    {
        queue->tail = NULL;
    }
    node->next = NULL;
    return node;
}

void TRLegacyDispatchRunBlockNode(TRLegacyDispatchBlockNode* node, bool use_autorelease_pool)
{
    __unsafe_unretained dispatch_block_t block = (__bridge dispatch_block_t)node->block;
    if (use_autorelease_pool)
    {
        @autoreleasepool
        {
            block();
        }
    }
    else
    {
        block();
    }
    TRLegacyDispatchDisposeCopiedBlock(node->block);
    free(node);
}

void TRLegacyDispatchQueueDestroy(TRLegacyDispatchQueue* queue)
{
    pthread_mutex_destroy(&queue->mutex);
    pthread_cond_destroy(&queue->cond);
    free(queue->label);
    free(queue);
}

bool TRLegacyDispatchSerialQueueShouldExitLocked(TRLegacyDispatchQueue* queue)
{
    return queue->refcount == 0 && queue->pending == 0;
}

void* TRLegacyDispatchSerialWorker(void* context)
{
    TRLegacyDispatchQueue* queue = static_cast<TRLegacyDispatchQueue*>(context);

    pthread_mutex_lock(&queue->mutex);
    for (;;)
    {
        while (queue->head == NULL && !TRLegacyDispatchSerialQueueShouldExitLocked(queue))
        {
            pthread_cond_wait(&queue->cond, &queue->mutex);
        }

        if (TRLegacyDispatchSerialQueueShouldExitLocked(queue))
        {
            pthread_mutex_unlock(&queue->mutex);
            TRLegacyDispatchQueueDestroy(queue);
            return NULL;
        }

        TRLegacyDispatchBlockNode* node = TRLegacyDispatchQueuePopLocked(queue);
        pthread_mutex_unlock(&queue->mutex);

        TRLegacyDispatchRunBlockNode(node, true);

        pthread_mutex_lock(&queue->mutex);
        --queue->pending;
        if (TRLegacyDispatchSerialQueueShouldExitLocked(queue))
        {
            pthread_cond_signal(&queue->cond);
        }
    }
}

void TRLegacyDispatchMainQueuePerform(void* info)
{
    TRLegacyDispatchQueue* queue = static_cast<TRLegacyDispatchQueue*>(info);

    for (;;)
    {
        pthread_mutex_lock(&queue->mutex);
        TRLegacyDispatchBlockNode* node = TRLegacyDispatchQueuePopLocked(queue);
        pthread_mutex_unlock(&queue->mutex);

        if (node == NULL)
        {
            return;
        }

        TRLegacyDispatchRunBlockNode(node, false);

        pthread_mutex_lock(&queue->mutex);
        --queue->pending;
        pthread_mutex_unlock(&queue->mutex);
    }
}

void TRLegacyDispatchMainQueueInit(void)
{
    CFRunLoopSourceContext context = {};
    context.info = &gMainQueue;
    context.perform = TRLegacyDispatchMainQueuePerform;

    gMainQueue.run_loop_source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    if (gMainQueue.run_loop_source == NULL)
    {
        abort();
    }

    CFRunLoopRef main_run_loop = CFRunLoopGetMain();
    gMainRunLoop = main_run_loop;
    CFRetain(gMainRunLoop);
    CFRunLoopAddSource(main_run_loop, gMainQueue.run_loop_source, kCFRunLoopDefaultMode);
    CFRunLoopAddSource(main_run_loop, gMainQueue.run_loop_source, CFSTR("NSModalPanelRunLoopMode"));
    CFRunLoopAddSource(main_run_loop, gMainQueue.run_loop_source, CFSTR("NSEventTrackingRunLoopMode"));
}

TRLegacyDispatchBlockNode* TRLegacyDispatchCreateBlockNode(__unsafe_unretained dispatch_block_t block)
{
    TRLegacyDispatchBlockNode* node = static_cast<TRLegacyDispatchBlockNode*>(calloc(1, sizeof(TRLegacyDispatchBlockNode)));
    if (node == NULL)
    {
        abort();
    }

    node->block = TRLegacyDispatchCopyBlock(block);
    if (node->block == NULL)
    {
        free(node);
        abort();
    }

    return node;
}

} // namespace

extern "C" void dispatch_once(dispatch_once_t* predicate, __unsafe_unretained dispatch_block_t block)
{
    if (__sync_bool_compare_and_swap(predicate, TRDispatchOnceNotStarted, TRDispatchOnceInProgress))
    {
        block();
        __sync_synchronize();

        pthread_mutex_lock(&gOnceMutex);
        *predicate = TRDispatchOnceDone;
        pthread_cond_broadcast(&gOnceCond);
        pthread_mutex_unlock(&gOnceMutex);
        return;
    }

    if (__sync_fetch_and_add(predicate, 0) == TRDispatchOnceDone)
    {
        __sync_synchronize();
        return;
    }

    pthread_mutex_lock(&gOnceMutex);
    while (*predicate != TRDispatchOnceDone)
    {
        pthread_cond_wait(&gOnceCond, &gOnceMutex);
    }
    pthread_mutex_unlock(&gOnceMutex);
    __sync_synchronize();
}

extern "C" dispatch_queue_t dispatch_get_main_queue(void)
{
    pthread_once(&gMainQueueInitOnce, TRLegacyDispatchMainQueueInit);
    return &gMainQueue;
}

extern "C" dispatch_queue_t dispatch_queue_create(char const* label, dispatch_queue_attr_t attr)
{
    if (attr != DISPATCH_QUEUE_SERIAL)
    {
        return NULL;
    }

    TRLegacyDispatchQueue* queue = static_cast<TRLegacyDispatchQueue*>(calloc(1, sizeof(TRLegacyDispatchQueue)));
    if (queue == NULL)
    {
        return NULL;
    }

    queue->kind = TRLegacyDispatchQueueKindSerial;
    queue->label = label != NULL ? strdup(label) : NULL;
    queue->refcount = 1;

    if (pthread_mutex_init(&queue->mutex, NULL) != 0 || pthread_cond_init(&queue->cond, NULL) != 0)
    {
        if (queue->label != NULL)
        {
            free(queue->label);
        }
        free(queue);
        return NULL;
    }

    pthread_t thread;
    int const error = pthread_create(&thread, NULL, TRLegacyDispatchSerialWorker, queue);
    if (error != 0)
    {
        pthread_mutex_destroy(&queue->mutex);
        pthread_cond_destroy(&queue->cond);
        if (queue->label != NULL)
        {
            free(queue->label);
        }
        free(queue);
        return NULL;
    }

    queue->worker_started = true;
    pthread_detach(thread);
    return queue;
}

extern "C" void dispatch_async(dispatch_queue_t queue, __unsafe_unretained dispatch_block_t block)
{
    if (queue == NULL || block == NULL)
    {
        return;
    }

    if (queue->kind == TRLegacyDispatchQueueKindMain)
    {
        dispatch_get_main_queue();
    }

    TRLegacyDispatchBlockNode* node = TRLegacyDispatchCreateBlockNode(block);

    pthread_mutex_lock(&queue->mutex);
    if (queue->closing)
    {
        pthread_mutex_unlock(&queue->mutex);
        TRLegacyDispatchDisposeCopiedBlock(node->block);
        free(node);
        return;
    }

    TRLegacyDispatchQueuePushLocked(queue, node);

    if (queue->kind == TRLegacyDispatchQueueKindMain)
    {
        CFRunLoopSourceSignal(queue->run_loop_source);
        CFRunLoopWakeUp(gMainRunLoop != NULL ? gMainRunLoop : CFRunLoopGetMain());
    }
    else
    {
        pthread_cond_signal(&queue->cond);
    }
    pthread_mutex_unlock(&queue->mutex);
}

extern "C" void dispatch_retain(dispatch_queue_t queue)
{
    if (queue == NULL || queue->kind == TRLegacyDispatchQueueKindMain)
    {
        return;
    }

    pthread_mutex_lock(&queue->mutex);
    if (!queue->closing)
    {
        ++queue->refcount;
    }
    pthread_mutex_unlock(&queue->mutex);
}

extern "C" void dispatch_release(dispatch_queue_t queue)
{
    if (queue == NULL || queue->kind == TRLegacyDispatchQueueKindMain)
    {
        return;
    }

    pthread_mutex_lock(&queue->mutex);
    if (queue->refcount > 0)
    {
        --queue->refcount;
        if (queue->refcount == 0)
        {
            queue->closing = true;
            pthread_cond_signal(&queue->cond);
        }
    }
    pthread_mutex_unlock(&queue->mutex);
}

#endif
