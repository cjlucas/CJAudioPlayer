//
//  OBJCHTTPDataSource.h
//  Audjustable
//
//  Created by Chris Lucas on 7/28/13.
//
//

#import "DataSource.h"

#define CJHTTPCachedDataSourceDebug 0

@class CJHTTPCachedDataSource;

@protocol CJHTTPCachedDataSourceInfoDelegate <NSObject>

@optional

- (void)dataSourceDidBeginDownloading:(CJHTTPCachedDataSource *)dataSource;
- (void)dataSource:(CJHTTPCachedDataSource *)dataSource didUpdateDownloadProgressWithBytesDownloaded:(NSUInteger)bytesDownloaded bytesExpected:(NSUInteger)bytesExpected;
- (void)dataSourceDidFinishDownloading:(CJHTTPCachedDataSource *)dataSource;
@end

@interface CJHTTPCachedDataSource : DataSource <NSURLSessionDataDelegate> {
    NSMutableData *_audioBuffer;
    NSMutableData *_cacheBuffer;

    // These ranges reflect the current position of the cache relative to the full file
    NSRange _currentAudioBufferRange;
    NSRange _currentCacheBufferRange;

    unsigned long long _cacheFileSize;

    BOOL _hasSeeked;
    dispatch_queue_t _bufferPrimerQueue;

    NSUInteger _totalBytesDownloaded; // don't rely on NSURLSessionDataTask, countOfBytesReceived tends to get ahead of the didReceiveData calls
    BOOL _usingTemporaryCacheFile;
    AudioFileTypeID _fileTypeID;

#if CJHTTPCachedDataSourceDebug
    // log cache hits
    int _writeCount;
    int _readCount;
#endif
}

//- (id)initWithURL:(NSURL *)url;
- (id)initWithHTTPURL:(NSURL *)httpURL cacheURL:(NSURL *)cacheURL queueID:(NSObject *)queueID;
- (void)startBuffering;

- (void)teardown;

@property (readonly) NSURL *httpURL;
@property (readonly) NSURL *cacheURL;
@property (readonly) id queueID;
@property (readonly, getter=isFullyCached) BOOL fullyCached;
@property id <CJHTTPCachedDataSourceInfoDelegate> infoDelegate;

@end
