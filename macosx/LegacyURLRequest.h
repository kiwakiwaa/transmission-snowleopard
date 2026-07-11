// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <Foundation/Foundation.h>

#include <libtransmission/macos-version.h>

typedef void (^TRURLDataCompletionHandler)(NSData* data, NSURLResponse* response, NSError* error);
typedef void (^TRURLDownloadProgressHandler)(long long bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef void (^TRURLDownloadCompletionHandler)(NSURL* location, NSURLResponse* response, NSError* error);

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
typedef NS_ENUM(NSUInteger, TRURLRequestTaskKind) { TRURLRequestTaskKindData, TRURLRequestTaskKindDownload };
#endif

@interface TRURLRequestTask : NSObject
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    NSURLRequest* _request;
    TRURLRequestTaskKind _kind;
    TRURLDataCompletionHandler _dataCompletionHandler;
    TRURLDownloadProgressHandler _progressHandler;
    TRURLDownloadCompletionHandler _downloadCompletionHandler;
    NSURLResponse* _response;
    NSMutableData* _receivedData;
    NSURL* _downloadLocation;
    BOOL _finished;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSURLSession* _session;
    NSURLSessionTask* _task;
#else
    NSURLConnection* _connection;
#endif
}
#endif

+ (TRURLRequestTask*)dataTaskWithRequest:(NSURLRequest*)request completionHandler:(TRURLDataCompletionHandler)completionHandler;
+ (TRURLRequestTask*)downloadTaskWithRequest:(NSURLRequest*)request
                             progressHandler:(TRURLDownloadProgressHandler)progressHandler
                           completionHandler:(TRURLDownloadCompletionHandler)completionHandler;

- (void)resume;
- (void)cancel;

@end
