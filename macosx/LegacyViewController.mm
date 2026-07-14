// This file Copyright (c) Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyViewController.h"

#if TR_MACOS_USE_LEGACY_VIEW_CONTROLLER

#import <CoreFoundation/CoreFoundation.h>

@interface LegacyViewController ()
- (id)_autounbinder;
- (id)_representedObject;
- (id)_view;
- (id)_nibWithName:(id)nibName bundle:(id)nibBundle;
- (void)_setTopLevelObjects:(id)topLevelObjects;
- (id)_nibBundleIdentifier;
- (void)_setNibBundleIdentifier:(id)nibBundleIdentifier;
- (void)_setNibName:(id)nibName;
- (id)_topEditor;
- (void)_editor:(id)editor didCommit:(BOOL)didCommit withOriginalDelegateInvocation:(void*)invocation;
- (void)objectDidBeginEditing:(id)editor;
- (void)objectDidEndEditing:(id)editor;
@end

@interface NSObject (TRLegacyViewControllerPrivateMessages)
- (BOOL)ibIsDecodingDesignTimeContent;
- (id)initWithBindingTarget:(id)bindingTarget;
- (void)retainBindingTargetAndUnbind;
@end

@interface NSBundle (TRLegacyViewControllerPrivateMessages)
+ (NSBundle*)currentNibLoadingBundle;
@end

namespace
{

NSString* TRLegacyViewControllerFrameName(SEL selector)
{
    return [NSString stringWithFormat:@"-[%@ %@]", @"NSViewController", NSStringFromSelector(selector)];
}

id TRLegacyCurrentNibLoadingBundle()
{
    Class bundleClass = [NSBundle class];
    return [bundleClass respondsToSelector:@selector(currentNibLoadingBundle)] ? [NSBundle currentNibLoadingBundle] : nil;
}

void TRLegacyReleaseNibTopLevelObjects(NSArray* topLevelObjects)
{
    SEL releaseSelector = NSSelectorFromString(@"release");
    for (NSUInteger i = 0; i < [topLevelObjects count]; ++i)
    {
        id object = [topLevelObjects objectAtIndex:i];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [object performSelector:releaseSelector];
#pragma clang diagnostic pop
    }
}

void* TRLegacyRetainInvocation(NSInvocation* invocation)
{
    return (__bridge_retained void*)invocation;
}

void TRLegacyReleaseRetainedInvocation(void* invocation)
{
    (void)(__bridge_transfer id)invocation;
}

}

@implementation LegacyViewController

- (id)init
{
    return [self initWithNibName:nil bundle:nil];
}

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    if ((self = [super init]))
    {
        _nibName = [nibNameOrNil copy];
        _nibBundle = nibBundleOrNil;
    }

    return self;
}

- (id)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        _nibName = [[coder decodeObjectForKey:@"NSNibName"] copy];
        _title = [[coder decodeObjectForKey:@"NSTitle"] copy];
        view = [coder decodeObjectForKey:@"NSView"];

        id nibBundleIdentifier = [coder decodeObjectForKey:@"NSNibBundleIdentifier"];
        if ([coder respondsToSelector:@selector(ibIsDecodingDesignTimeContent)] && [coder ibIsDecodingDesignTimeContent])
        {
            _designNibBundleIdentifier = [nibBundleIdentifier copy];
        }
        else if (nibBundleIdentifier != nil)
        {
            _nibBundle = [NSBundle bundleWithIdentifier:nibBundleIdentifier];
            if (_nibBundle == nil)
            {
                [NSException raise:NSInternalInconsistencyException
                            format:@"%@ could not instantiate an NSViewController for a nib in the \"%@\" bundle because the bundle has not been loaded.",
                                   TRLegacyViewControllerFrameName(_cmd), nibBundleIdentifier];
            }
        }
        else
        {
            NSBundle* currentNibLoadingBundle = TRLegacyCurrentNibLoadingBundle();
            if ([currentNibLoadingBundle pathForResource:_nibName ofType:@"nib"] != nil)
            {
                _nibBundle = currentNibLoadingBundle;
            }
        }
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    if (_nibName != nil)
    {
        [coder encodeObject:_nibName forKey:@"NSNibName"];
    }
    if (_title != nil)
    {
        [coder encodeObject:_title forKey:@"NSTitle"];
    }
    if ([self nibName] == nil && view != nil)
    {
        [coder encodeObject:view forKey:@"NSView"];
    }

    NSString* nibBundleIdentifier = [self _nibBundleIdentifier];
    if (nibBundleIdentifier == nil && _nibBundle != [NSBundle mainBundle])
    {
        nibBundleIdentifier = [_nibBundle bundleIdentifier];
    }
    if (nibBundleIdentifier != nil)
    {
        [coder encodeObject:nibBundleIdentifier forKey:@"NSNibBundleIdentifier"];
    }
}

- (void)dealloc
{
    SEL unbindSelector = NSSelectorFromString(@"retainBindingTargetAndUnbind");
    if ([_autounbinder respondsToSelector:unbindSelector])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_autounbinder performSelector:unbindSelector];
#pragma clang diagnostic pop
    }
}

- (void)setRepresentedObject:(id)representedObject
{
    if (_representedObject != representedObject)
    {
        _representedObject = representedObject;
    }
}

- (id)representedObject
{
    return _representedObject;
}

- (id)_representedObject
{
    return _representedObject;
}

- (void)setTitle:(NSString*)title
{
    if (_title != title)
    {
        _title = [title copy];
    }
}

- (NSString*)title
{
    return _title;
}

- (NSView*)view
{
    if (view == nil)
    {
        [self loadView];
    }

    return view;
}

- (id)_view
{
    return view;
}

- (void)loadView
{
    NSString* nibName = [self nibName];
    NSBundle* nibBundle = [self nibBundle];
    NSNib* nib = [self _nibWithName:nibName bundle:nibBundle];
    if (nib == nil)
    {
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@ could not load the \"%@\" nib.", TRLegacyViewControllerFrameName(_cmd), nibName];
    }

    NSArray* topLevelObjects = nil;
    if ([nib instantiateNibWithOwner:self topLevelObjects:&topLevelObjects])
    {
        [self _setTopLevelObjects:topLevelObjects];
        TRLegacyReleaseNibTopLevelObjects(topLevelObjects);
    }
    else
    {
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@ could not instantiate the \"%@\" nib.", TRLegacyViewControllerFrameName(_cmd), nibName];
    }

    if (view == nil)
    {
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@ loaded the \"%@\" nib but no view was set.", TRLegacyViewControllerFrameName(_cmd), nibName];
    }
}

- (NSString*)nibName
{
    return _nibName;
}

- (NSBundle*)nibBundle
{
    return _nibBundle;
}

- (id)_nibWithName:(id)nibName bundle:(id)nibBundle
{
    return [[NSNib alloc] initWithNibNamed:nibName bundle:nibBundle];
}

- (void)setView:(NSView*)newView
{
    if (view != newView)
    {
        view = newView;
    }
}

- (void)_setTopLevelObjects:(id)topLevelObjects
{
    if (_topLevelObjects != topLevelObjects)
    {
        _topLevelObjects = [topLevelObjects copy];
    }
}

- (id)_autounbinder
{
    if (_autounbinder == nil)
    {
        Class autounbinderClass = NSClassFromString(@"NSAutounbinder");
        if (autounbinderClass != Nil && [autounbinderClass instancesRespondToSelector:@selector(initWithBindingTarget:)])
        {
            _autounbinder = [[autounbinderClass alloc] initWithBindingTarget:self];
        }
    }

    return _autounbinder;
}

- (id)_nibBundleIdentifier
{
    return _designNibBundleIdentifier;
}

- (void)_setNibBundleIdentifier:(id)nibBundleIdentifier
{
    if (_designNibBundleIdentifier != nibBundleIdentifier)
    {
        _designNibBundleIdentifier = [nibBundleIdentifier copy];
    }
    _nibBundle = nil;
}

- (void)_setNibName:(id)nibName
{
    if (_nibName != nibName)
    {
        _nibName = [nibName copy];
    }
}

- (void)discardEditing
{
    for (id editor = [self _topEditor]; editor != nil; editor = [self _topEditor])
    {
        [editor discardEditing];
    }
}

- (BOOL)commitEditing
{
    for (id editor = [self _topEditor]; editor != nil; editor = [self _topEditor])
    {
        if (![editor commitEditing])
        {
            return NO;
        }
    }

    return YES;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void*)contextInfo
{
    NSMethodSignature* signature = [delegate methodSignatureForSelector:didCommitSelector];
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:delegate];
    [invocation setSelector:didCommitSelector];
    LegacyViewController* controller = self;
    [invocation setArgument:&controller atIndex:2];
    [invocation setArgument:&contextInfo atIndex:4];

    id editor = [self _topEditor];
    if (editor != nil)
    {
        [editor commitEditingWithDelegate:self
                        didCommitSelector:@selector(_editor:didCommit:withOriginalDelegateInvocation:)
                              contextInfo:TRLegacyRetainInvocation(invocation)];
    }
    else
    {
        BOOL didCommit = YES;
        [invocation setArgument:&didCommit atIndex:3];
        NSArray* modes = [NSArray arrayWithObject:(__bridge NSString*)kCFRunLoopCommonModes];
        [invocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0 inModes:modes];
    }
}

- (void)_editor:(id)editor didCommit:(BOOL)didCommit withOriginalDelegateInvocation:(void*)invocationContext
{
    (void)editor;
    NSInvocation* invocation = (__bridge NSInvocation*)invocationContext;
    id nextEditor = [self _topEditor];
    if (didCommit && nextEditor != nil)
    {
        [nextEditor commitEditingWithDelegate:self
                            didCommitSelector:@selector(_editor:didCommit:withOriginalDelegateInvocation:)
                                  contextInfo:invocationContext];
    }
    else
    {
        [invocation setArgument:&didCommit atIndex:3];
        [invocation invoke];
        TRLegacyReleaseRetainedInvocation(invocationContext);
    }
}

- (id)_topEditor
{
    for (NSInteger i = (NSInteger)_editors.count - 1; i >= 0; --i)
    {
        id editor = (__bridge id)[[_editors objectAtIndex:(NSUInteger)i] pointerValue];
        if (editor != nil)
        {
            return editor;
        }
    }

    return nil;
}

- (void)objectDidBeginEditing:(id)editor
{
    if (_editors == nil)
    {
        _editors = [[NSMutableArray alloc] init];
    }
    [_editors addObject:[NSValue valueWithPointer:(__bridge const void*)editor]];
}

- (void)objectDidEndEditing:(id)editor
{
    for (NSInteger i = (NSInteger)_editors.count - 1; i >= 0; --i)
    {
        if ([[_editors objectAtIndex:(NSUInteger)i] pointerValue] == (__bridge void*)editor)
        {
            [_editors removeObjectAtIndex:(NSUInteger)i];
            return;
        }
    }
}

@end

#endif
