// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "BlocklistDownloader.h"
#import "BlocklistDownloaderViewController.h"
#import "BlocklistScheduler.h"
#import "Controller.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
#import "LegacyURLRequest.h"
#endif

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
@interface BlocklistDownloader ()<NSURLSessionDownloadDelegate>

@property(nonatomic) NSURLSession* fSession;

#else
@interface BlocklistDownloader ()

@property(nonatomic) TRURLRequestTask* fTask;

#endif

@property(nonatomic) NSUInteger fCurrentSize;
@property(nonatomic) long long fExpectedSize;
@property(nonatomic) BlocklistDownloadState fState;

@end

@implementation BlocklistDownloader

BlocklistDownloader* fBLDownloader = nil;

+ (BlocklistDownloader*)downloader
{
    if (!fBLDownloader)
    {
        fBLDownloader = [[BlocklistDownloader alloc] init];
        [fBLDownloader startDownload];
    }

    return fBLDownloader;
}

+ (BOOL)isRunning
{
    return fBLDownloader != nil;
}

- (void)setViewController:(BlocklistDownloaderViewController*)viewController
{
    _viewController = viewController;
    if (_viewController)
    {
        switch (self.fState)
        {
        case BlocklistDownloadStateStart:
            [_viewController setStatusStarting];
            break;
        case BlocklistDownloadStateDownloading:
            [_viewController setStatusProgressForCurrentSize:self.fCurrentSize expectedSize:self.fExpectedSize];
            break;
        case BlocklistDownloadStateProcessing:
            [_viewController setStatusProcessing];
            break;
        }
    }
}

- (void)cancelDownload
{
    [_viewController setFinished];

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    [self.fSession invalidateAndCancel];
    self.fSession = nil;
#else
    [self.fTask cancel];
    self.fTask = nil;
#endif

    [BlocklistScheduler.scheduler updateSchedule];

    fBLDownloader = nil;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090

- (void)URLSession:(NSURLSession*)session
                 downloadTask:(NSURLSessionDownloadTask*)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    (void)bytesWritten;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.fState = BlocklistDownloadStateDownloading;

        self.fCurrentSize = totalBytesWritten;
        self.fExpectedSize = totalBytesExpectedToWrite;

        [self.viewController setStatusProgressForCurrentSize:self.fCurrentSize expectedSize:self.fExpectedSize];
    });
}

- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:(NSError*)error
{
    (void)session;
    (void)task;

    if (error)
    {
        [self downloadDidFailWithError:error];
    }
}

- (void)URLSession:(NSURLSession*)session
                 downloadTask:(NSURLSessionDownloadTask*)downloadTask
    didFinishDownloadingToURL:(NSURL*)location
{
    (void)session;

    [self downloadDidFinishToURL:location response:downloadTask.response];
}

#endif

- (void)downloadDidFailWithError:(NSError*)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.viewController setFailed:error.localizedDescription];
        NSDate* date = [NSDate date];
        NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
        [defaults setObject:date forKey:@"BlocklistNewLastUpdate"];
        [BlocklistScheduler.scheduler updateSchedule];

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
        [self.fSession finishTasksAndInvalidate];
        self.fSession = nil;
#else
        self.fTask = nil;
#endif
        fBLDownloader = nil;
    });
}

- (void)downloadDidFinishToURL:(NSURL*)location response:(NSURLResponse*)response
{
    self.fState = BlocklistDownloadStateProcessing;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.viewController setStatusProcessing];
    });

    NSString* filename = response.suggestedFilename;
    if (filename == nil)
    {
        filename = @"transmission-blocklist.tmp";
    }

    NSString* tempDir = NSTemporaryDirectory();
    NSString* tempFile = [tempDir stringByAppendingPathComponent:filename];
    NSString* blocklistFile = [tempDir stringByAppendingPathComponent:@"transmission-blocklist"];

    NSString* sourcePath = location.path;
    [NSFileManager.defaultManager moveItemAtPath:sourcePath toPath:tempFile error:nil];

    if ([@"text/plain" isEqualToString:response.MIMEType])
    {
        blocklistFile = tempFile;
    }
    else
    {
        NSURL* tempURL = [NSURL fileURLWithPath:tempFile];
        NSURL* blocklistURL = [NSURL fileURLWithPath:blocklistFile];
        [self decompressFrom:tempURL to:blocklistURL error:nil];
        [NSFileManager.defaultManager removeItemAtPath:tempFile error:nil];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        Controller* controller = (Controller*)[NSApp delegate];
        auto const count = tr_blocklistSetContent(controller.sessionHandle, blocklistFile.UTF8String);

        [NSFileManager.defaultManager removeItemAtPath:blocklistFile error:nil];

        if (count)
        {
            [self.viewController setFinished];
        }
        else
        {
            NSString* message = NSLocalizedString(@"The specified blocklist file did not contain any valid rules.", "blocklist fail message");
            [self.viewController setFailed:message];
        }

        NSDate* date = [NSDate date];
        NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
        [defaults setObject:date forKey:@"BlocklistNewLastUpdate"];
        [defaults setObject:date forKey:@"BlocklistNewLastUpdateSuccess"];
        [BlocklistScheduler.scheduler updateSchedule];

        [NSNotificationCenter.defaultCenter postNotificationName:@"BlocklistUpdated" object:nil];

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
        [self.fSession finishTasksAndInvalidate];
        self.fSession = nil;
#else
        self.fTask = nil;
#endif
        fBLDownloader = nil;
    });
}

#pragma mark - Private

- (void)startDownload
{
    self.fState = BlocklistDownloadStateStart;

    [BlocklistScheduler.scheduler cancelSchedule];

    NSString* urlString = [NSUserDefaults.standardUserDefaults stringForKey:@"BlocklistURL"];
    if (!urlString)
    {
        urlString = @"";
    }
    else
    {
        NSCharacterSet* whitespace = [NSCharacterSet whitespaceCharacterSet];
        urlString = [urlString stringByTrimmingCharactersInSet:whitespace];
        if (![urlString isEqualToString:@""] && [urlString rangeOfString:@"://"].location == NSNotFound)
        {
            urlString = [@"https://" stringByAppendingString:urlString];
        }
    }

    NSURL* url = [NSURL URLWithString:urlString];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    self.fSession = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:self
                                             delegateQueue:nil];

    NSURLSessionDownloadTask* task = [self.fSession downloadTaskWithRequest:request];
    [task resume];
#else
    self.fTask = [TRURLRequestTask downloadTaskWithRequest:request
        progressHandler:^(long long bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            (void)bytesWritten;

            dispatch_async(dispatch_get_main_queue(), ^{
                self.fState = BlocklistDownloadStateDownloading;

                self.fCurrentSize = totalBytesWritten;
                self.fExpectedSize = totalBytesExpectedToWrite;

                [self.viewController setStatusProgressForCurrentSize:self.fCurrentSize expectedSize:self.fExpectedSize];
            });
        } completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
            if (error)
            {
                [self downloadDidFailWithError:error];
            }
            else
            {
                [self downloadDidFinishToURL:location response:response];
            }
        }];
    [self.fTask resume];
#endif
}

- (BOOL)decompressFrom:(NSURL*)file to:(NSURL*)destination error:(NSError**)error
{
    if ([self untarFrom:file to:destination])
    {
        return YES;
    }

    if ([self unzipFrom:file to:destination])
    {
        return YES;
    }

    if ([self gunzipFrom:file to:destination])
    {
        return YES;
    }

    // If it doesn't look like archive just copy it to destination
    else
    {
        return [NSFileManager.defaultManager copyItemAtURL:file toURL:destination error:error];
    }
}

- (BOOL)untarFrom:(NSURL*)file to:(NSURL*)destination
{
    // We need to check validity of archive before listing or unpacking.
    NSTask* tarListCheck = [[NSTask alloc] init];

    tarListCheck.launchPath = @"/usr/bin/tar";
    tarListCheck.arguments = @[ @"--list", @"--file", file.path ];
    tarListCheck.standardOutput = nil;
    tarListCheck.standardError = nil;

    @try
    {
        [tarListCheck launch];
        [tarListCheck waitUntilExit];

        if (tarListCheck.terminationStatus != 0)
        {
            return NO;
        }
    }
    @catch (NSException* exception)
    {
        return NO;
    }

    NSTask* tarList = [[NSTask alloc] init];

    tarList.launchPath = @"/usr/bin/tar";
    tarList.arguments = @[ @"--list", @"--file", file.path ];

    NSPipe* pipe = [[NSPipe alloc] init];
    tarList.standardOutput = pipe;
    tarList.standardError = nil;

    NSString* filename;

    @try
    {
        [tarList launch];
        [tarList waitUntilExit];

        if (tarList.terminationStatus != 0)
        {
            return NO;
        }

        NSData* data = [pipe.fileHandleForReading readDataToEndOfFile];

        NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        filename = [[output componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] objectAtIndex:0];
    }
    @catch (NSException* exception)
    {
        return NO;
    }

    // It's a directory, skip
    if ([filename hasSuffix:@"/"])
    {
        return NO;
    }

    NSURL* destinationDir = destination.URLByDeletingLastPathComponent;

    NSTask* untar = [[NSTask alloc] init];
    untar.launchPath = @"/usr/bin/tar";
    untar.currentDirectoryPath = destinationDir.path;
    untar.arguments = @[ @"--extract", @"--file", file.path, filename ];

    @try
    {
        [untar launch];
        [untar waitUntilExit];

        if (untar.terminationStatus != 0)
        {
            return NO;
        }
    }
    @catch (NSException* exception)
    {
        return NO;
    }

    NSURL* result = [destinationDir URLByAppendingPathComponent:filename];

    [NSFileManager.defaultManager moveItemAtURL:result toURL:destination error:nil];
    return YES;
}

- (BOOL)gunzipFrom:(NSURL*)file to:(NSURL*)destination
{
    NSURL* destinationDir = destination.URLByDeletingLastPathComponent;

    NSTask* gunzip = [[NSTask alloc] init];
    gunzip.launchPath = @"/usr/bin/gunzip";
    gunzip.currentDirectoryPath = destinationDir.path;
    gunzip.arguments = @[ @"--keep", @"--force", file.path ];

    @try
    {
        [gunzip launch];
        [gunzip waitUntilExit];

        if (gunzip.terminationStatus != 0)
        {
            return NO;
        }
    }
    @catch (NSException* exception)
    {
        return NO;
    }

    NSURL* result = file.URLByDeletingPathExtension;

    [NSFileManager.defaultManager moveItemAtURL:result toURL:destination error:nil];
    return YES;
}

- (BOOL)unzipFrom:(NSURL*)file to:(NSURL*)destination
{
    NSTask* zipinfo = [[NSTask alloc] init];
    zipinfo.launchPath = @"/usr/bin/zipinfo";
    zipinfo.arguments = @[
        @"-1", /* just the filename */
        file.path /* source zip file */
    ];
    NSPipe* pipe = [[NSPipe alloc] init];
    zipinfo.standardOutput = pipe;
    zipinfo.standardError = nil;

    NSString* filename;

    @try
    {
        [zipinfo launch];
        [zipinfo waitUntilExit];

        if (zipinfo.terminationStatus != 0)
        {
            return NO;
        }

        NSData* data = [pipe.fileHandleForReading readDataToEndOfFile];

        NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        filename = [[output componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] objectAtIndex:0];
    }
    @catch (NSException* exception)
    {
        return NO;
    }

    // It's a directory, skip
    if ([filename hasSuffix:@"/"])
    {
        return NO;
    }

    NSURL* destinationDir = destination.URLByDeletingLastPathComponent;

    NSTask* unzip = [[NSTask alloc] init];
    unzip.launchPath = @"/usr/bin/unzip";
    unzip.currentDirectoryPath = destinationDir.path;
    unzip.arguments = @[ file.path, filename ];

    @try
    {
        [unzip launch];
        [unzip waitUntilExit];

        if (unzip.terminationStatus != 0)
        {
            return NO;
        }
    }
    @catch (NSException* exception)
    {
        return NO;
    }

    NSURL* result = [destinationDir URLByAppendingPathComponent:filename];

    [NSFileManager.defaultManager moveItemAtURL:result toURL:destination error:nil];
    return YES;
}

@end
