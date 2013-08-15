//
//  OBJCHTTPDataSource.m
//  Audjustable
//
//  Created by Chris Lucas on 7/28/13.
//
//

#ifndef CJLog
#define BASEFILENAME (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#define CJLog(fmt, ...) do { NSLog(@"[%s:%d (%@)] %s " fmt, BASEFILENAME, __LINE__, self, __PRETTY_FUNCTION__, __VA_ARGS__); } while(0)
#endif

#define CJHTTPCachedDataSourceLog(fmt, ...) do { if (CJHTTPCachedDataSourceDebug) { CJLog(fmt, __VA_ARGS__); } } while(0)

#define CJHTTPCachedDataSourceMaxAudioBufferSize (512 * 1024) // 512 KB
#define CJHTTPCachedDataSourceMaxCacheBufferSize (1 * 1024 * 1024) // 1 MB

#import "CJHTTPCachedDataSource.h"

@interface CJHTTPCachedDataSource ()

- (void)setup;

- (void)primeAudioBuffer;
- (void)fillAudioBufferFromCache;
//- (void)fillAudioBufferFromCacheWithNewAudioBuffer:(NSMutableData *)newAudioBuffer withOffset:(NSUInteger)offset withBytesLeft:(NSUInteger)bytesLeft;
- (void)purgeCacheBuffer;
- (void)purgeAudioBuffer;

- (void)handleReceivedData:(NSData *)data; // controls where new data is written
- (void)handleDownloadCompletion;

// Cache Methods
- (NSURL *)temporaryCacheURL;
- (void)invalidateCacheFile;
- (void)createCacheFile;
- (NSFileHandle *)cacheWriteFileHandler;
- (NSFileHandle *)cacheReadFileHandler;
- (void)writeDataToFile:(NSData *)cachedData purgeCache:(BOOL)purgeCache;
- (NSData *)readDataFromFileAtOffset:(NSUInteger)offset numBytes:(NSUInteger)numBytes;

- (void)setFileTypeIDWithMIMEType:(NSString *)mimeType;
- (void)setFileTypeIDWithURL:(NSURL *)url;

@property NSURLSession *urlSession;
@property NSURLSessionDataTask *dataTask;

@end

@implementation CJHTTPCachedDataSource

@synthesize httpURL = _httpURL;
@synthesize cacheURL = _cacheURL;
@synthesize queueID = _queueID;
@synthesize fullyCached = _fullyCached;

#pragma mark - Lifecycle
- (id)initWithHTTPURL:(NSURL *)httpURL cacheURL:(NSURL *)cacheURL queueID:(NSObject *)queueID
{
    if (self = [super init]) {
        [self setup];

        _httpURL    = [httpURL copy];
        _cacheURL   = cacheURL ? [cacheURL copy] : [self temporaryCacheURL];
        _queueID    = queueID;
        _usingTemporaryCacheFile = !cacheURL;

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:_httpURL];
        req.timeoutInterval = 30;
        self.urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
        self.dataTask = [self.urlSession dataTaskWithRequest:req];

        // check if cache exists, create it if it doesnt
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_cacheURL.path error:nil];
        if (attributes) {
            // if the cache file exists, we can assume it's complete.
            _fullyCached = YES;
            _finalCacheSize = [attributes fileSize];
        }
        else {
            _fullyCached = NO;
            [self createCacheFile];
        }
    }

    return self;
}

- (void)dealloc
{
    CJHTTPCachedDataSourceLog(@"dealloc", nil);
    [self teardown];
}

- (void)setup
{
    _fileTypeID = 0;
    _currentAudioBufferRange = NSMakeRange(0, 0);
    _currentCacheBufferRange  = NSMakeRange(0, 0);
    _bufferPrimerQueue = dispatch_queue_create("com.chrisjlucas.cjaudioplayer.datasource.bufferprimer", DISPATCH_QUEUE_SERIAL);
    _downloadDataQueue = dispatch_queue_create("com.chrisjlucas.cjaudioplayer.datasource.downloaddata", DISPATCH_QUEUE_SERIAL);

    _audioBuffer = [[NSMutableData alloc] initWithCapacity:CJHTTPCachedDataSourceMaxAudioBufferSize];
    _cacheBuffer = [[NSMutableData alloc] initWithCapacity:CJHTTPCachedDataSourceMaxCacheBufferSize];

    _hasSeeked = NO;
    _dataSourceEOF = NO;
    _totalBytesDownloaded = 0;
    _finalCacheSize = 0;
}

- (void)teardown
{
    [_audioBuffer replaceBytesInRange:NSMakeRange(0, _audioBuffer.length) withBytes:NULL length:0];
    [_cacheBuffer replaceBytesInRange:NSMakeRange(0, _audioBuffer.length) withBytes:NULL length:0];

    if (_usingTemporaryCacheFile || !_fullyCached) {
        [self invalidateCacheFile];
    }

    [self.urlSession invalidateAndCancel];
}

#pragma mark -

- (void)startBuffering
{
    CJHTTPCachedDataSourceLog(@"is fully cached? %@", _fullyCached ? @"YES" : @"NO");
//    CJHTTPCachedDataSourceLog(@"final audio buffer range: %@", NSStringFromRange(_currentAudioBufferRange));
//    CJHTTPCachedDataSourceLog(@"final cache buffer range: %@", NSStringFromRange(_currentCacheBufferRange));

    if (_fullyCached) {
        [self primeAudioBuffer];
    } else {
        [self.dataTask resume];
    }
}

- (void)primeAudioBuffer
{
    dispatch_async(_bufferPrimerQueue, ^{
        // no need to go further if eof has already been called
        if (_dataSourceEOF) {
            return;
        }

        // only refill buffer if it's empty
        if (self.hasBytesAvailable) {
            [self.delegate dataSourceDataAvailable:self];
            return;
        } else {
            [self fillAudioBufferFromCache];
        }

        if (_currentAudioBufferRange.length > CJHTTPCachedDataSourceMaxAudioBufferSize)
            CJHTTPCachedDataSourceLog(@"WARNING: currentAudioBufferRange length is greater than max audio buffer size: %d", _currentAudioBufferRange.length);

        CJHTTPCachedDataSourceLog(@"hasBytesAvailable? %@", self.hasBytesAvailable ? @"YES" : @"NO");

        if (self.hasBytesAvailable) {
            [self.delegate dataSourceDataAvailable:self];
        } else if (_fullyCached) {
            CJHTTPCachedDataSourceLog(@"calling EOF", nil);
#if CJHTTPCachedDataSourceDebug
            CJHTTPCachedDataSourceLog(@"final write count:  %d", _writeCount);
            CJHTTPCachedDataSourceLog(@"final read count:   %d", _readCount);
            CJHTTPCachedDataSourceLog(@"final buffer count: %d", _bufferCount);
#endif
            CJHTTPCachedDataSourceLog(@"final audio buffer range: %@", NSStringFromRange(_currentAudioBufferRange));
            CJHTTPCachedDataSourceLog(@"final cache buffer range: %@", NSStringFromRange(_currentCacheBufferRange));

            _dataSourceEOF = YES;
            [self.delegate dataSourceEof:self];
        }
    });
}

- (void)fillAudioBufferFromCache
{
    @synchronized(self) {
//        CJHTTPCachedDataSourceLog(@"%@", NSStringFromRange(_currentAudioBufferRange));
//        CJHTTPCachedDataSourceLog(@"%@", NSStringFromRange(_currentCacheBufferRange));

        _audioBuffer = [[NSMutableData alloc] initWithCapacity:CJHTTPCachedDataSourceMaxAudioBufferSize];

        NSInteger locationDiff = _currentAudioBufferRange.location - _currentCacheBufferRange.location;
        if (locationDiff >= 0 && _currentCacheBufferRange.length > 0) {
#if CJHTTPCachedDataSourceDebug
            _bufferCount++;
#endif
            NSUInteger endRange = MIN(_currentCacheBufferRange.length - locationDiff, CJHTTPCachedDataSourceMaxAudioBufferSize);
            [_audioBuffer appendData:[_cacheBuffer subdataWithRange:NSMakeRange(locationDiff, endRange)]];
        } else {
            if (_currentCacheBufferRange.length > 0) {
                [self writeDataToFile:_cacheBuffer purgeCache:YES];
            }
            [_audioBuffer appendData:[self readDataFromFileAtOffset:_currentAudioBufferRange.location numBytes:CJHTTPCachedDataSourceMaxAudioBufferSize]];
        }

//        CJHTTPCachedDataSourceLog(@"fillAudioBufferFromCache (before read)", nil);
//        CJHTTPCachedDataSourceLog(@"audio buffer location: %d", _currentAudioBufferRange.location);
//        CJHTTPCachedDataSourceLog(@"audio buffer length: %d", _audioBuffer.length);
//        CJHTTPCachedDataSourceLog(@"cache buffer length: %d", _cacheBuffer.length);

        _currentAudioBufferRange.length = _audioBuffer.length;

//        CJHTTPCachedDataSourceLog(@"fillAudioBufferFromCache (after read)", nil);
//        CJHTTPCachedDataSourceLog(@"audio buffer location: %d", _currentAudioBufferRange.location);
//        CJHTTPCachedDataSourceLog(@"audio buffer length: %d", _audioBuffer.length);
//        CJHTTPCachedDataSourceLog(@"cache buffer length: %d", _cacheBuffer.length);
    }
}

- (void)handleReceivedData:(NSData *)data
{
    dispatch_async(_downloadDataQueue, ^{
        @synchronized(self) {
//            CJHTTPCachedDataSourceLog(@"handleReceivedData (count: %d)", data.length);
//            CJHTTPCachedDataSourceLog(@"_currentCacheBufferRange: %@", NSStringFromRange(_currentCacheBufferRange));
//            CJHTTPCachedDataSourceLog(@"%@", _fullyCached ? @"YES" : @"NO");

            if (_fullyCached)
                return;

            // if appending new data is going to put the cache buffer over the size threshold, write to disk and empty cache
            if ((_currentCacheBufferRange.length + data.length) > CJHTTPCachedDataSourceMaxCacheBufferSize) {
                [self writeDataToFile:_cacheBuffer purgeCache:YES];
            }

            if (data.length > CJHTTPCachedDataSourceMaxCacheBufferSize) {
                CJHTTPCachedDataSourceLog(@"incoming data (%d bytes) too large for cache, directly to disk", data.length);
                [self writeDataToFile:data purgeCache:NO];
            } else {
                [_cacheBuffer appendData:data];
                _currentCacheBufferRange.length += data.length;
            }
        };
    });
}

- (void)handleDownloadCompletion
{
    dispatch_async(_downloadDataQueue, ^{
        @synchronized(self) {
            CJHTTPCachedDataSourceLog(@"handleDownloadCompletion", nil);
            [self writeDataToFile:_cacheBuffer purgeCache:YES];

            [self primeAudioBuffer];
        }
    });
}

- (void)purgeCacheBuffer
{
    // remove written bytes
    [_cacheBuffer replaceBytesInRange:NSMakeRange(0, _cacheBuffer.length) withBytes:NULL length:0];

    // shift cache buffer location
    NSUInteger newLocation = _currentCacheBufferRange.location + _currentCacheBufferRange.length;

    // reset range to reflect empty cache buffer}
    _currentCacheBufferRange = NSMakeRange(newLocation, 0);
}

- (void)purgeAudioBuffer
{
    [_audioBuffer replaceBytesInRange:NSMakeRange(0, _audioBuffer.length) withBytes:NULL length:0];

    _currentAudioBufferRange = NSMakeRange(0, 0);
}

#pragma mark - File Cache Methods

- (NSURL *)temporaryCacheURL
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *cacheDir = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];

    NSURL *cacheFile;
    do {
        cacheFile = [cacheDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%d", arc4random()]];
    } while ([fm fileExistsAtPath:cacheFile.path isDirectory:NO]);

    _usingTemporaryCacheFile = YES;

    CJHTTPCachedDataSourceLog(@"%@", cacheFile);
    return cacheFile;
}

- (NSFileHandle *)cacheWriteFileHandler
{
    return [NSFileHandle fileHandleForWritingToURL:_cacheURL error:nil];
}

- (NSFileHandle *)cacheReadFileHandler
{
    return [NSFileHandle fileHandleForReadingFromURL:_cacheURL error:nil];
}

- (void)writeDataToFile:(NSData *)cachedData purgeCache:(BOOL)purgeCache
{
#if CJHTTPCachedDataSourceDebug
    _writeCount++;
#endif
    CJHTTPCachedDataSourceLog(@"writeDataToFile (count: %d)", cachedData.length);

    NSFileHandle *fp = [self cacheWriteFileHandler];

    [fp seekToEndOfFile];
    [fp writeData:cachedData];
    [fp closeFile];

    if (purgeCache)
        [self purgeCacheBuffer];

    if (_finalCacheSize > 0 && _currentCacheBufferRange.location == _finalCacheSize) {
        _fullyCached = YES;
    }
}

- (NSData *)readDataFromFileAtOffset:(NSUInteger)offset numBytes:(NSUInteger)numBytes
{
#if CJHTTPCachedDataSourceDebug
    _readCount++;
#endif
    CJHTTPCachedDataSourceLog(@"readDataFromFileAtOffset: %d numBytes: %d", offset, numBytes);

    NSFileHandle *fp = [self cacheReadFileHandler];

    [fp seekToFileOffset:offset];
    NSData *data = [fp readDataOfLength:numBytes];

    [fp closeFile];

    return data;
}

- (void)invalidateCacheFile

{
    _fullyCached = NO;
    [[NSFileManager defaultManager] removeItemAtURL:_cacheURL error:nil];
}

- (void)createCacheFile
{
    [[NSFileManager defaultManager] createFileAtPath:_cacheURL.path contents:nil attributes:nil];
}

#pragma mark - DataSource methods

- (void)close
{
    CJHTTPCachedDataSourceLog(@"close", nil);
    [self teardown];
}

- (BOOL)hasBytesAvailable
{
    return _currentAudioBufferRange.length > 0;
}

- (int)readIntoBuffer:(UInt8 *)buffer withSize:(int)size
{
    @synchronized(self) {
        CJHTTPCachedDataSourceLog(@"readInfoBuffer withSize: %d", size);

        // read bytes from internal buffer into audio player buffer
        [_audioBuffer getBytes:buffer length:size];

        // use min in case buffer size is smaller than the size requested
        NSUInteger bytesRead = MIN(_currentAudioBufferRange.length, size);

        if (bytesRead == 0) {
            CJHTTPCachedDataSourceLog(@"WARNING: bytesRead was zero", nil);
        }

        // remove bytes from internal buffer that just copied to audio player buffer
        [_audioBuffer replaceBytesInRange:NSMakeRange(0, bytesRead) withBytes:NULL length:0];

        _currentAudioBufferRange.location += bytesRead;
        _currentAudioBufferRange.length -= bytesRead;

        CJHTTPCachedDataSourceLog(@"currentAudioBufferRange: %@", NSStringFromRange(_currentAudioBufferRange));

        if (_fullyCached) {
            [self primeAudioBuffer];
        }

        return bytesRead;
    }
}

- (AudioFileTypeID)audioFileTypeHint
{
    if (_fileTypeID == 0) {
        CJHTTPCachedDataSourceLog(@"WARNING: _fileTypeID isn't set yet", nil);
    }

    return _fileTypeID;
}

- (void)setFileTypeIDWithMIMEType:(NSString *)mimeType
{
    if ([mimeType isEqualToString:@"audio/mpeg"]) {
        _fileTypeID = kAudioFileMP3Type;
    }
}

- (void)setFileTypeIDWithURL:(NSURL *)url
{
    NSString *ext = [[url.path pathExtension] lowercaseString];

    if ([ext isEqualToString:@"mp3"]) {
        _fileTypeID = kAudioFileMP3Type;
    }
}

- (long long)position
{
    return _currentAudioBufferRange.location;
}

- (long long)length
{
    return _finalCacheSize;
}

- (void)seekToOffset:(long long)offset
{
    CJHTTPCachedDataSourceLog(@"seekToOffset: %lld", offset);
    _hasSeeked = offset > 0; // AudioPlayer will sometimes seek to zero before playing, don't consider that as having seeked

    [self purgeAudioBuffer];

    _currentAudioBufferRange.location = offset;

    [self primeAudioBuffer];

    // if fully cached, just prime buffer at new offset
    // otherwise, we have to make a new http request with the range selected and invalidate the current cache
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ { %@ }", [super description], _httpURL];
}

- (BOOL)registerForEvents:(NSRunLoop *)runLoop
{
    CJHTTPCachedDataSourceLog(@"registerForEvents", nil);
    [self startBuffering];
    
    return NO;
}

#pragma mark - NSURLSessionDataDelegate methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    CJHTTPCachedDataSourceLog(@"%@", response);

    [self setFileTypeIDWithMIMEType:response.MIMEType];
    NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;

    if (response.expectedContentLength == _finalCacheSize) {
        CJHTTPCachedDataSourceLog(@"expected content length matches size of cache file", nil);
        _fullyCached = YES;
        [self primeAudioBuffer];
        disposition = NSURLSessionResponseCancel;
    } else if (_finalCacheSize > 0) {
        // if file has been changed server-side, we need to invalidate the current cache and redownload
        [self invalidateCacheFile];
        [self createCacheFile];
    }

    _finalCacheSize = response.expectedContentLength;

    completionHandler(disposition);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
//#if CJHTTPCachedDataSourceDebug
//    @synchronized(self) {
//        CJHTTPCachedDataSourceLog(@"total received data: %lld", dataTask.countOfBytesReceived);
//        CJHTTPCachedDataSourceLog(@"data count: %d", data.length);
//    }
//#endif

    _totalBytesDownloaded += data.length;
    if ([self.infoDelegate respondsToSelector:@selector(dataSource:didUpdateDownloadProgressWithBytesDownloaded:bytesExpected:)]) {
        [self.infoDelegate dataSource:self didUpdateDownloadProgressWithBytesDownloaded:_totalBytesDownloaded bytesExpected:dataTask.countOfBytesExpectedToReceive];
    }
    [self handleReceivedData:data];
    [self primeAudioBuffer];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    CJHTTPCachedDataSourceLog(@"didCompleteWithError: %@", error);
    if (error) {
        [self.delegate dataSourceErrorOccured:self];
        [self teardown];
    }

    _finalCacheSize = task.countOfBytesReceived;

    [self handleDownloadCompletion];

    [self.urlSession invalidateAndCancel];

    if ([self.infoDelegate respondsToSelector:@selector(dataSourceDidFinishDownloading:)]) {
        [self.infoDelegate dataSourceDidFinishDownloading:self];
    }
}

@end
