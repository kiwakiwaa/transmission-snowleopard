// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

@class BlocklistDownloaderViewController;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
@class NSURLSession;
#else
@class TRURLRequestTask;
#endif

typedef NS_ENUM(NSUInteger, BlocklistDownloadState) {
    BlocklistDownloadStateStart,
    BlocklistDownloadStateDownloading,
    BlocklistDownloadStateProcessing
};

@interface BlocklistDownloader : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    BlocklistDownloaderViewController* _viewController;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSURLSession* _fSession;
#else
    TRURLRequestTask* _fTask;
#endif
    NSUInteger _fCurrentSize;
    long long _fExpectedSize;
    BlocklistDownloadState _fState;
}
#endif

@property(nonatomic) BlocklistDownloaderViewController* viewController;
@property(nonatomic, class, readonly) BOOL isRunning;

+ (BlocklistDownloader*)downloader; //starts download if not already occurring

- (void)cancelDownload;

@end
