//
//  SUAppcast.h
//  Sparkle
//
//  Created by Andy Matuschak on 3/12/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SUAPPCAST_H
#define SUAPPCAST_H

@protocol SUAppcastDelegate;

// Codex 10.6 i386 compatibility: 10.6 SDK exposes NSURLDownload delegate callbacks informally.
#if !defined(MAC_OS_X_VERSION_10_7) || MAC_OS_X_VERSION_MAX_ALLOWED < 1070
@protocol NSURLDownloadDelegate <NSObject>
@end
#endif

@class SUAppcastItem;
@interface SUAppcast : NSObject<NSURLDownloadDelegate>
{
@private
	NSArray *items;
	NSString *userAgentString;
	id<SUAppcastDelegate> delegate;
	NSString *downloadFilename;
	NSURLDownload *download;
}
@property (assign) id<SUAppcastDelegate> delegate;
@property (copy) NSString *userAgentString;

- (void)fetchAppcastFromURL:(NSURL *)url;

- (NSArray *)items;
@end

@protocol SUAppcastDelegate <NSObject>
- (void)appcastDidFinishLoading:(SUAppcast *)appcast;
- (void)appcast:(SUAppcast *)appcast failedToLoadWithError:(NSError *)error;
@end

#endif
