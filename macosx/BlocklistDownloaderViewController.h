// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
#import <AppKit/AppKit.h>
#else
#import <Foundation/Foundation.h>
#endif

@class PrefsController;

@interface BlocklistDownloaderViewController : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSWindow* _fStatusWindow;
    IBOutlet NSProgressIndicator* _fProgressBar;
    IBOutlet NSTextField* _fTextField;
    IBOutlet NSButton* _fButton;
    PrefsController* _fPrefsController;
}
#endif

+ (void)downloadWithPrefsController:(PrefsController*)prefsController;

- (IBAction)cancelDownload:(id)sender;

- (void)setStatusStarting;
- (void)setStatusProgressForCurrentSize:(NSUInteger)currentSize expectedSize:(long long)expectedSize;
- (void)setStatusProcessing;

- (void)setFinished;
- (void)setFailed:(NSString*)error;

@end
