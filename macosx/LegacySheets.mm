// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacySheets.h"

#include <libtransmission/macos-version.h>

@interface TRSheetCallback : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    TRSheetCompletionHandler _handler;
}
#endif

@property(nonatomic, copy) TRSheetCompletionHandler handler;

- (instancetype)initWithCompletionHandler:(TRSheetCompletionHandler)handler;
- (void)sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
- (void)alertDidEnd:(NSAlert*)alert returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;

@end

@implementation TRSheetCallback

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize handler = _handler;
#endif

- (instancetype)initWithCompletionHandler:(TRSheetCompletionHandler)handler
{
    if ((self = [super init]))
    {
        self.handler = handler;
    }

    return self;
}

- (void)sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
    [sheet orderOut:nil];
    if (self.handler)
    {
        self.handler(returnCode);
    }

    CFBridgingRelease(contextInfo);
}

- (void)alertDidEnd:(NSAlert*)alert returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
    [alert.window orderOut:nil];
    if (self.handler)
    {
        self.handler(returnCode);
    }

    CFBridgingRelease(contextInfo);
}

@end

#pragma mark - Panel Sheets

static void TRBeginPanelSheetModalForWindowImpl(
    NSSavePanel* panel,
    NSWindow* window,
    NSString* name,
    TRSheetCompletionHandler handler)
{
#if TR_MACOS_DEPLOYMENT_BEFORE_10_6
    if ([panel respondsToSelector:@selector(beginSheetModalForWindow:completionHandler:)])
    {
        [panel beginSheetModalForWindow:window completionHandler:handler];
        return;
    }

    TRSheetCallback* callback = handler ? [[TRSheetCallback alloc] initWithCompletionHandler:handler] : nil;
    void* contextInfo = callback ? (void*)CFBridgingRetain(callback) : NULL;
    SEL const didEndSelector = callback ? @selector(sheetDidEnd:returnCode:contextInfo:) : NULL;

    if ([panel isKindOfClass:[NSOpenPanel class]])
    {
        NSOpenPanel* openPanel = (NSOpenPanel*)panel;
        [openPanel beginSheetForDirectory:[openPanel directory]
                                    file:nil
                                   types:[openPanel allowedFileTypes]
                          modalForWindow:window
                           modalDelegate:callback
                          didEndSelector:didEndSelector
                             contextInfo:contextInfo];
    }
    else
    {
        [panel beginSheetForDirectory:[panel directory]
                                 file:name
                       modalForWindow:window
                        modalDelegate:callback
                       didEndSelector:didEndSelector
                          contextInfo:contextInfo];
    }
#else
    (void)name;
    [panel beginSheetModalForWindow:window completionHandler:handler];
#endif
}

void TRBeginPanelSheetModalForWindow(NSSavePanel* panel, NSWindow* window, TRSheetCompletionHandler handler)
{
    TRBeginPanelSheetModalForWindowImpl(panel, window, nil, handler);
}

void TRBeginSavePanelSheetModalForWindow(
    NSSavePanel* panel,
    NSWindow* window,
    NSString* name,
    TRSheetCompletionHandler handler)
{
    TRBeginPanelSheetModalForWindowImpl(panel, window, name, handler);
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@implementation NSWindow (TransmissionCompatibility)

- (void)beginSheet:(NSWindow*)sheet completionHandler:(TRSheetCompletionHandler)handler
{
    TRSheetCallback* callback = handler ? [[TRSheetCallback alloc] initWithCompletionHandler:handler] : nil;
    void* contextInfo = callback ? (void*)CFBridgingRetain(callback) : NULL;

    [NSApp beginSheet:sheet modalForWindow:self modalDelegate:callback
        didEndSelector:callback ? @selector(sheetDidEnd:returnCode:contextInfo:) : NULL
           contextInfo:contextInfo];
}

- (void)endSheet:(NSWindow*)sheet
{
    [NSApp endSheet:sheet];
    [sheet orderOut:nil];
}

@end

@implementation NSAlert (TransmissionCompatibility)

- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(TRSheetCompletionHandler)handler
{
    TRSheetCallback* callback = handler ? [[TRSheetCallback alloc] initWithCompletionHandler:handler] : nil;
    void* contextInfo = callback ? (void*)CFBridgingRetain(callback) : NULL;

    [self beginSheetModalForWindow:window modalDelegate:callback
                    didEndSelector:callback ? @selector(alertDidEnd:returnCode:contextInfo:) : NULL
                       contextInfo:contextInfo];
}

@end
#endif
