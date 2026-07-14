// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#if TR_MACOS_SDK_BEFORE_10_9
typedef NSInteger NSModalResponse;
static NSModalResponse const NSModalResponseOK = 1;
static NSModalResponse const NSModalResponseCancel = 0;
#endif

typedef void (^TRSheetCompletionHandler)(NSModalResponse returnCode);

#if TR_MACOS_SDK_BEFORE_10_6
@interface NSSavePanel (TRLegacyPanelSheetDeclarations)
- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(TRSheetCompletionHandler)handler;
@end
#endif

void TRBeginPanelSheetModalForWindow(NSSavePanel* panel, NSWindow* window, TRSheetCompletionHandler handler);
void TRBeginSavePanelSheetModalForWindow(
    NSSavePanel* panel,
    NSWindow* window,
    NSString* name,
    TRSheetCompletionHandler handler);

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@interface NSWindow (TransmissionCompatibility)
- (void)beginSheet:(NSWindow*)sheet completionHandler:(TRSheetCompletionHandler)handler;
- (void)endSheet:(NSWindow*)sheet;
@end

@interface NSAlert (TransmissionCompatibility)
- (void)beginSheetModalForWindow:(NSWindow*)window completionHandler:(TRSheetCompletionHandler)handler;
@end
#endif
