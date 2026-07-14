// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "LegacyURLRequest.h"
#import "CocoaCompatibility.h"

#include <libtransmission/macos-version.h>

#if !TR_MACOS_OBJC_FRAGILE_RUNTIME
typedef NS_ENUM(NSUInteger, TRURLRequestTaskKind) { TRURLRequestTaskKindData, TRURLRequestTaskKindDownload };
#endif

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
@interface TRURLRequestTask ()<NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
#else
@interface TRURLRequestTask ()<NSURLConnectionDataDelegate, NSURLConnectionDownloadDelegate>
#endif

@property(nonatomic) NSURLRequest* request;
@property(nonatomic) TRURLRequestTaskKind kind;
@property(nonatomic, copy) TRURLDataCompletionHandler dataCompletionHandler;
@property(nonatomic, copy) TRURLDownloadProgressHandler progressHandler;
@property(nonatomic, copy) TRURLDownloadCompletionHandler downloadCompletionHandler;
@property(nonatomic) NSURLResponse* response;
@property(nonatomic) NSMutableData* receivedData;
@property(nonatomic) NSURL* downloadLocation;
@property(nonatomic) BOOL finished;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
@property(nonatomic) NSURLSession* session;
@property(nonatomic) NSURLSessionTask* task;
#else
@property(nonatomic) NSURLConnection* connection;
#endif

@end

@implementation TRURLRequestTask

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize request = _request;
@synthesize kind = _kind;
@synthesize dataCompletionHandler = _dataCompletionHandler;
@synthesize progressHandler = _progressHandler;
@synthesize downloadCompletionHandler = _downloadCompletionHandler;
@synthesize response = _response;
@synthesize receivedData = _receivedData;
@synthesize downloadLocation = _downloadLocation;
@synthesize finished = _finished;
#endif

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize session = _session;
@synthesize task = _task;
#endif
#else
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize connection = _connection;
#endif
#endif

+ (TRURLRequestTask*)dataTaskWithRequest:(NSURLRequest*)request completionHandler:(TRURLDataCompletionHandler)completionHandler
{
    TRURLRequestTask* task = [[self alloc] initWithRequest:request kind:TRURLRequestTaskKindData];
    task.dataCompletionHandler = completionHandler;
    return task;
}

+ (TRURLRequestTask*)downloadTaskWithRequest:(NSURLRequest*)request
                             progressHandler:(TRURLDownloadProgressHandler)progressHandler
                           completionHandler:(TRURLDownloadCompletionHandler)completionHandler
{
    TRURLRequestTask* task = [[self alloc] initWithRequest:request kind:TRURLRequestTaskKindDownload];
    task.progressHandler = progressHandler;
    task.downloadCompletionHandler = completionHandler;
    return task;
}

- (instancetype)initWithRequest:(NSURLRequest*)request kind:(TRURLRequestTaskKind)kind
{
    if ((self = [super init]))
    {
        _request = request;
        _kind = kind;
        _receivedData = [[NSMutableData alloc] init];
    }

    return self;
}

- (void)resume
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    self.task = self.kind == TRURLRequestTaskKindDownload ? [self.session downloadTaskWithRequest:self.request] :
                                                            [self.session dataTaskWithRequest:self.request];
    [self.task resume];
#else
#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self];
#else
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:TRMainRunLoop() forMode:NSRunLoopCommonModes];
    [self.connection start];
#endif
#endif
}

- (void)cancel
{
    self.finished = YES;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    [self.task cancel];
    [self.session invalidateAndCancel];
#else
    [self.connection cancel];
#endif
}

- (void)finishDataWithError:(NSError*)error
{
    if (self.finished)
    {
        return;
    }
    self.finished = YES;

    TRURLDataCompletionHandler completionHandler = self.dataCompletionHandler;
    NSData* data = self.receivedData;
    NSURLResponse* response = self.response;
    [self invalidate];

    if (completionHandler)
    {
        completionHandler(data, response, error);
    }
}

- (void)finishDownloadToLocation:(NSURL*)location error:(NSError*)error
{
    if (self.finished)
    {
        return;
    }
    self.finished = YES;

    TRURLDownloadCompletionHandler completionHandler = self.downloadCompletionHandler;
    NSURLResponse* response = self.response;
    [self invalidate];

    if (completionHandler)
    {
        completionHandler(location, response, error);
    }
}

- (void)invalidate
{
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    [self.session finishTasksAndInvalidate];
    self.task = nil;
    self.session = nil;
#else
    self.connection = nil;
#endif
}

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9

- (void)URLSession:(NSURLSession*)session
              dataTask:(NSURLSessionDataTask*)dataTask
    didReceiveResponse:(NSURLResponse*)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.response = response;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)dataTask didReceiveData:(NSData*)data
{
    [self.receivedData appendData:data];
}

- (void)URLSession:(NSURLSession*)session
                 downloadTask:(NSURLSessionDownloadTask*)downloadTask
    didFinishDownloadingToURL:(NSURL*)location
{
    self.downloadLocation = location;
    self.response = downloadTask.response;
}

- (void)URLSession:(NSURLSession*)session
                 downloadTask:(NSURLSessionDownloadTask*)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    TRURLDownloadProgressHandler progressHandler = self.progressHandler;
    if (progressHandler)
    {
        progressHandler(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:(NSError*)error
{
    self.response = task.response ?: self.response;
    if (self.kind == TRURLRequestTaskKindData)
    {
        [self finishDataWithError:error];
    }
    else
    {
        [self finishDownloadToLocation:self.downloadLocation error:error];
    }
}

#else

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    self.response = response;
    [self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection*)connection
          didWriteData:(long long)bytesWritten
     totalBytesWritten:(long long)totalBytesWritten
    expectedTotalBytes:(long long)totalBytesExpectedToWrite
{
    TRURLDownloadProgressHandler progressHandler = self.progressHandler;
    if (progressHandler)
    {
        progressHandler(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    [self finishDataWithError:nil];
}

- (void)connectionDidFinishDownloading:(NSURLConnection*)connection destinationURL:(NSURL*)destinationURL
{
    [self finishDownloadToLocation:destinationURL error:nil];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (self.kind == TRURLRequestTaskKindData)
    {
        [self finishDataWithError:error];
    }
    else
    {
        [self finishDownloadToLocation:nil error:error];
    }
}

#endif

@end
