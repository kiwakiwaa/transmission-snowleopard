// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyAnimationContext.h"

#if TR_MACOS_SDK_BEFORE_10_5 || TR_MACOS_DEPLOYMENT_BEFORE_10_5

extern "C" void* _Block_copy(void const* block);
extern "C" void _Block_release(void const* block);

static NSString* const TRLegacyAnimationContextStackKey = @"org.transmission.LegacyAnimationContext.stack";

static NSMutableArray* TRLegacyAnimationContextStackForCurrentThread(void)
{
    NSMutableDictionary* threadDictionary = [[NSThread currentThread] threadDictionary];
    NSMutableArray* stack = [threadDictionary objectForKey:TRLegacyAnimationContextStackKey];
    if (stack == nil)
    {
        stack = [[NSMutableArray alloc] init];
        [threadDictionary setObject:stack forKey:TRLegacyAnimationContextStackKey];
    }

    return stack;
}

@implementation LegacyAnimationContext

@synthesize duration = _duration;
@synthesize allowsImplicitAnimation = _allowsImplicitAnimation;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _duration = 0.25;
    }

    return self;
}

- (void)dealloc
{
    if (_completionHandler != NULL)
    {
        _Block_release(_completionHandler);
    }
}

- (void (^)(void))completionHandler
{
    return (__bridge void (^)(void))_completionHandler;
}

- (void)setCompletionHandler:(__unsafe_unretained void (^)(void))completionHandler
{
    void* const copiedCompletionHandler =
        completionHandler != nil ? _Block_copy((__bridge void const*)completionHandler) : NULL;
    if (_completionHandler != NULL)
    {
        _Block_release(_completionHandler);
    }

    _completionHandler = copiedCompletionHandler;
}

- (id)copyWithZone:(NSZone*)zone
{
    LegacyAnimationContext* copy = [[[self class] allocWithZone:zone] init];
    copy.duration = self.duration;
    copy.allowsImplicitAnimation = self.allowsImplicitAnimation;
    return copy;
}

+ (void)beginGrouping
{
    NSMutableArray* stack = TRLegacyAnimationContextStackForCurrentThread();
    LegacyAnimationContext* context = stack.count == 0 ? [[self alloc] init] : [stack.lastObject copy];
    [stack addObject:context];
}

+ (void)endGrouping
{
    NSMutableArray* stack = TRLegacyAnimationContextStackForCurrentThread();
    if (stack.count == 0)
    {
        return;
    }

    LegacyAnimationContext* context = stack.lastObject;
    void* completionHandler = context->_completionHandler;
    context->_completionHandler = NULL;
    [stack removeLastObject];

    if (completionHandler != NULL)
    {
        ((__bridge void (^)(void))completionHandler)();
        _Block_release(completionHandler);
    }
}

+ (LegacyAnimationContext*)currentContext
{
    NSMutableArray* stack = TRLegacyAnimationContextStackForCurrentThread();
    if (stack.count == 0)
    {
        LegacyAnimationContext* context = [[self alloc] init];
        [stack addObject:context];
    }

    return stack.lastObject;
}

+ (void)runAnimationGroup:(__unsafe_unretained void (^)(LegacyAnimationContext* context))changes
        completionHandler:(__unsafe_unretained void (^)(void))completionHandler
{
    [self beginGrouping];
    self.currentContext.completionHandler = completionHandler;

    if (changes != nil)
    {
        changes(self.currentContext);
    }

    [self endGrouping];
}

@end

#endif
