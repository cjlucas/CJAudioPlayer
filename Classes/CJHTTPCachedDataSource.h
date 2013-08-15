//
//  OBJCHTTPDataSource.h
//  Audjustable
//
//  Created by Chris Lucas on 7/28/13.
//
//

#import "DataSource.h"

#define CJHTTPCachedDataSourceDebug 1

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

    // These ranges reflect the current position of the buffer relative to the full cache file
    NSRange _currentAudioBufferRange;
    NSRange _currentCacheBufferRange;

    dispatch_queue_t _bufferPrimerQueue; // TODO: rename these
    dispatch_queue_t _downloadDataQueue;

    BOOL _hasSeeked;
    BOOL _dataSourceEOF;
    BOOL _usingTemporaryCacheFile;

    NSUInteger _totalBytesDownloaded; // don't rely on NSURLSessionDataTask, countOfBytesReceived tends to get ahead of the didReceiveData calls
    NSUInteger _finalCacheSize; // set when either file is already fully cached during initialization or when download is complete

    AudioFileTypeID _fileTypeID;

#if CJHTTPCachedDataSourceDebug
    // log cache hits
    int _bufferCount;
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
