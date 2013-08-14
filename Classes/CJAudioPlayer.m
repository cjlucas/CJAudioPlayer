//
//  CJDataSourceQueueManager.m
//  Audjustable
//
//  Created by Chris Lucas on 7/29/13.
//
//

#import "CJAudioPlayer.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

#ifndef CJLog
#define BASEFILENAME (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#define CJLog(fmt, ...) do { NSLog(@"[%s:%d] %s " fmt, BASEFILENAME, __LINE__, __PRETTY_FUNCTION__, __VA_ARGS__); } while(0)
#endif

#define CJAudioPlayerLog(fmt, ...) do { if (CJAudioPlayerDebug) { CJLog(fmt, __VA_ARGS__); } } while(0)

NSString * NSStringFromAudioPlayerState(AudioPlayerState state)
{
    NSString *str;

    switch (state) {
        case AudioPlayerStateReady:
            str = @"AudioPlayerStateReady";
            break;
        case AudioPlayerStateRunning:
            str = @"AudioPlayerStateRunning";
            break;
        case AudioPlayerStatePlaying:
            str = @"AudioPlayerStatePlaying";
            break;
        case AudioPlayerStatePaused:
            str = @"AudioPlayerStatePaused";
            break;
        case AudioPlayerStateStopped:
            str = @"AudioPlayerStateStopped";
            break;
        case AudioPlayerStateError:
            str = @"AudioPlayerStateError";
            break;
        case AudioPlayerStateDisposed:
            str = @"AudioPlayerStateDisposed";
            break;
        default:
            break;
    }

    return str;
}

NSString * NSStringFromAudioPlayerInternalState(AudioPlayerInternalState state)
{
    NSString *str;

    switch (state) {
        case AudioPlayerInternalStateInitialised:
            str = @"AudioPlayerInternalStateInitialised";
            break;
        case AudioPlayerInternalStateRunning:
            str = @"AudioPlayerInternalStateRunning";
            break;
        case AudioPlayerInternalStatePlaying:
            str = @"AudioPlayerInternalStatePlaying";
            break;
        case AudioPlayerInternalStateStartingThread:
            str = @"AudioPlayerInternalStateStartingThread";
            break;
        case AudioPlayerInternalStateWaitingForData:
            str = @"AudioPlayerInternalStateWaitingForData";
            break;
        case AudioPlayerInternalStateWaitingForQueueToStart:
            str = @"AudioPlayerInternalStateWaitingForQueueToStart";
            break;
        case AudioPlayerInternalStatePaused:
            str = @"AudioPlayerInternalStatePaused";
            break;
        case AudioPlayerInternalStateRebuffering:
            str = @"AudioPlayerInternalStateRebuffering";
            break;
        case AudioPlayerInternalStateStopping:
            str = @"AudioPlayerInternalStateStopping";
            break;
        case AudioPlayerInternalStateStopped:
            str = @"AudioPlayerInternalStateStopped";
            break;
        case AudioPlayerInternalStateDisposed:
            str = @"AudioPlayerInternalStateDisposed";
            break;
        case AudioPlayerInternalStateError:
            str = @"AudioPlayerInternalStateError";
            break;
        default:
            break;
    }

    return str;
}

NSString * NSStringFromAudioPlayerStopReason(AudioPlayerStopReason reason)
{
    NSString *str;

    switch (reason) {
        case AudioPlayerStopReasonNoStop:
            str = @"AudioPlayerStopReasonNoStop";
            break;
        case AudioPlayerStopReasonEof:
            str = @"AudioPlayerStopReasonEof";
            break;
        case AudioPlayerStopReasonUserAction:
            str = @"AudioPlayerStopReasonUserAction";
            break;
        case AudioPlayerStopReasonUserActionFlushStop:
            str = @"AudioPlayerStopReasonUserActionFlushStop";
            break;
        default:
            break;
    }

    return str;
}

NSString * NSStringFromAudioPlayerErrorCode(AudioPlayerErrorCode code)
{
    NSString *str;

    switch (code) {
        case AudioPlayerErrorNone:
            str = @"AudioPlayerErrorNone";
            break;
        case AudioPlayerErrorDataSource:
            str = @"AudioPlayerErrorDataSource";
            break;
        case AudioPlayerErrorStreamParseBytesFailed:
            str = @"AudioPlayerErrorStreamParseBytesFailed";
            break;
        case AudioPlayerErrorDataNotFound:
            str = @"AudioPlayerErrorDataNotFound";
            break;
        case AudioPlayerErrorQueueStartFailed:
            str = @"AudioPlayerErrorQueueStartFailed";
            break;
        case AudioPlayerErrorQueuePauseFailed:
            str = @"AudioPlayerErrorQueuePauseFailed";
            break;
        case AudioPlayerErrorUnknownBuffer:
            str = @"AudioPlayerErrorUnknownBuffer";
            break;
        case AudioPlayerErrorQueueStopFailed:
            str = @"AudioPlayerErrorQueueStopFailed";
            break;
        case AudioPlayerErrorOther:
            str = @"AudioPlayerErrorOther";
            break;
        default:
            break;
    }

    return str;
}


@interface CJAudioPlayer ()

- (void)setup;
- (void)teardown;

- (void)activateAudioSession;
- (void)deactivateAudioSession;
- (void)handleAudioSessionInterruption:(NSNotification *)notification;

- (id <CJAudioPlayerQueueItem>)getNextItem; // returns nil if no next item
- (id <CJAudioPlayerQueueItem>)getPreviousItem; // returns nil if no previous item
- (id <CJAudioPlayerQueueItem>)itemForQueueID:(id)queueID;

- (void)shuffleQueue;

// convenience methods
- (CJHTTPCachedDataSource *)dataSourceForItem:(id <CJAudioPlayerQueueItem>)item;
- (void)setItem:(id <CJAudioPlayerQueueItem>)item; // creates and sets data source
- (void)queueItem:(id <CJAudioPlayerQueueItem>)item; // creates and queues data source

- (void)flushStop;

@property BOOL buffering;

@end

@implementation CJAudioPlayer

@synthesize shuffleModeEnabled = _shuffleModeEnabled;
@synthesize buffering = _buffering;

#pragma mark - Lifecycle

- (id)init
{
    if (self = [super init]) {
        [self setup];
    }

    return self;
}

- (void)setup
{
    _items = [[NSMutableArray alloc] init];
    _queue = [[NSMutableArray alloc] init];
    _player = [[AudioPlayer alloc] init];
    _player.delegate = self;
    _buffering = NO;

    [self resetItems];

    [self activateAudioSession];
}

- (void)teardown
{
    [self deactivateAudioSession];
}

- (void)dealloc
{
    [self teardown];
}

#pragma mark -

- (id <CJAudioPlayerQueueItem>)getNextItem
{
    id <CJAudioPlayerQueueItem> item;
    NSInteger nextQueuePosition = _currentQueuePosition + 1;

    if (nextQueuePosition >= _queue.count) {
        item = [self isContinuousModeEnabled] ? [_queue objectAtIndex:0] : nil;
    } else {
        item = [_queue objectAtIndex:nextQueuePosition];
    }

    return item;
}

- (id <CJAudioPlayerQueueItem>)getPreviousItem
{
    id <CJAudioPlayerQueueItem> item;
    NSInteger nextQueuePosition = _currentQueuePosition - 1;

    if (nextQueuePosition < 0) {
        item = [self isContinuousModeEnabled] ? [_queue lastObject] : nil;
    } else {
        item = [_queue objectAtIndex:nextQueuePosition];
    }

    return item;
}

- (NSArray *)items
{
    return [_items copy];
}

- (NSArray *)queue
{
    return [_queue copy];
}

- (void)setBuffering:(BOOL)buffering
{
    if (_buffering && !buffering) { // from YES to NO
        if ([self.delegate respondsToSelector:@selector(audioPlayerDidFinishBuffering:)]) {
            [self.delegate audioPlayerDidFinishBuffering:self];
        }
    } else if (!_buffering && buffering) { // from NO to YES
        if ([self.delegate respondsToSelector:@selector(audioPlayerDidBeginBuffering:)]) {
            [self.delegate audioPlayerDidBeginBuffering:self];
        }
    }

    _buffering = buffering;
}

- (BOOL)buffering
{
    return _buffering;
}

- (void)setShuffleModeEnabled:(BOOL)shuffleModeEnabled
{
    if (_shuffleModeEnabled && !shuffleModeEnabled) { // from YES to NO
        _queue = [_items mutableCopy];
        _currentQueuePosition = self.currentItem ? [_queue indexOfObject:self.currentItem] : 0;
    } else if (!_shuffleModeEnabled && shuffleModeEnabled) { // from NO to YES
        [self shuffleQueue];
    }

    _shuffleModeEnabled = shuffleModeEnabled;
}

- (BOOL)isShuffleModeEnabled
{
    return _shuffleModeEnabled;
}

- (void)addItem:(id<CJAudioPlayerQueueItem>)item
{
    [_items addObject:item];
    [_queue addObject:item];

    if (self.shuffleModeEnabled) {
        [self shuffleQueue];
    }
}

- (void)shuffleQueue
{
    NSMutableArray *newQueue = [[NSMutableArray alloc] initWithCapacity:_queue.count];

    // if there is a currently playing item, add it to the top of the new queue
    if (self.currentItem) {
        [newQueue addObject:self.currentItem];
        [_queue removeObject:self.currentItem];
    }

    while (_queue.count > 0) {
        int randomIndex = arc4random() % _queue.count;

        [newQueue addObject:[_queue objectAtIndex:randomIndex]];
        [_queue removeObjectAtIndex:randomIndex];
    }

    _queue = newQueue;
    _currentQueuePosition = 0;

}

- (id <CJAudioPlayerQueueItem>)itemForQueueID:(id)queueID
{
    id <CJAudioPlayerQueueItem> item = nil;

    for (id <CJAudioPlayerQueueItem> queueItem in _queue) {
        if ([queueItem queueID] == queueID) {
            item = queueItem;
            break;
        }
    }

    return item;
}

- (id <CJAudioPlayerQueueItem>)currentItem
{
    return _player.currentlyPlayingQueueItemId ? [self itemForQueueID:_player.currentlyPlayingQueueItemId] : nil;
}

- (void)resetItems
{
    [self flushStop];

    [_items removeAllObjects];
    [_queue removeAllObjects];
    _currentQueuePosition = 0;
}

- (void)flushStop
{
    [_player flushStop];

    [_currentDataSource teardown];
    _currentDataSource = nil;

    [_queuedDataSource teardown];
    _queuedDataSource = nil;
}

- (BOOL)hasNextItem
{
    return [self getNextItem] != nil;
}

- (BOOL)hasPreviousItem
{
    return [self getPreviousItem] != nil;
}

- (CJHTTPCachedDataSource *)dataSourceForItem:(id<CJAudioPlayerQueueItem>)item
{
    CJHTTPCachedDataSource *dataSource = [[CJHTTPCachedDataSource alloc] initWithHTTPURL:[item httpURL] cacheURL:[item cacheURL] queueID:[item queueID]];
    dataSource.infoDelegate = self;

    return dataSource;
}

- (void)setItem:(id<CJAudioPlayerQueueItem>)item
{
    if (item == nil)
        return;

    [self flushStop];

    CJHTTPCachedDataSource *dataSource = [self dataSourceForItem:item];
    CJAudioPlayerLog(@"setting item: %@ with queueID: %@", item, [item queueID]);
    CJAudioPlayerLog(@"%@", dataSource);
    [_player setDataSource:dataSource withQueueItemId:[item queueID]];
    _currentDataSource = dataSource;
}

- (void)queueItem:(id<CJAudioPlayerQueueItem>)item
{
    if (item == nil)
        return;

    if (_queuedDataSource != nil)
        CJAudioPlayerLog(@"WARNING: we're trying to queue a data source while _queueDataSource != nil", nil);

    CJHTTPCachedDataSource *dataSource = [self dataSourceForItem:item];

    CJAudioPlayerLog(@"queueing item: %@ with queueID: %@", item, [item queueID]);
    [_player queueDataSource:dataSource withQueueItemId:[item queueID]];
    _queuedDataSource = dataSource;
}

- (double)progress
{
    return _player.progress;
}

- (double)duration
{
    return _player.duration;
}

#pragma mark - Controls

- (void)play
{
    if (_player.currentlyPlayingQueueItemId == nil) {
        id item = [_queue objectAtIndex:0];
        [self setItem:item];
    } else {
        [_player resume];
    }

}

- (void)playItem:(id<CJAudioPlayerQueueItem>)item
{
    assert([_queue containsObject:item]);

    [self setItem:item];
}

- (void)pause
{
    [_player pause];
}

- (void)togglePlayPause
{
    if (_player.state == AudioPlayerStatePlaying) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)playNext
{
    CJAudioPlayerLog(@"queue pos: %d", _currentQueuePosition);

    id <CJAudioPlayerQueueItem> item = [self getNextItem];
    if (item) {
        [self flushStop];
        [self setItem:item];
    }
}

- (void)playPrevious
{
    id <CJAudioPlayerQueueItem> item = [self getPreviousItem];

    if (item) {
        [self flushStop];
        [self setItem:item];
    }
}

#pragma mark - AVAudioSession methods

- (void)activateAudioSession
{
    AVAudioSession *as = [AVAudioSession sharedInstance];
    NSError *error;

    [as setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error)
        CJAudioPlayerLog(@"%@", error);

    error = nil;

    [as setActive:YES error:&error];
    if (error)
        CJAudioPlayerLog(@"%@", error);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:@"AVAudioSessionInterruptionNotification" object:as];
}

- (void)deactivateAudioSession
{
    [[AVAudioSession sharedInstance] setActive:NO error:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification
{
    if (![notification.name isEqualToString:@"AVAudioSessionInterruptionNotification"]) {
        return;
    }

    NSUInteger interruptionType = [((NSNumber *)notification.userInfo[AVAudioSessionInterruptionTypeKey]) intValue];

    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self pause];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self play];
            break;

        default:
            break;
    }
}

#pragma mark - AudioPlayerDelegate methods

-(void) audioPlayer:(AudioPlayer*)audioPlayer stateChanged:(AudioPlayerState)state
{
    CJAudioPlayerLog(@"stateChanged: %@", NSStringFromAudioPlayerState(state));
}

- (void)audioPlayer:(AudioPlayer *)audioPlayer internalStateChanged:(AudioPlayerInternalState)state
{
    CJAudioPlayerLog(@"internalStateChanged: %@", NSStringFromAudioPlayerInternalState(state));

    self.buffering = state == AudioPlayerInternalStateWaitingForData || state == AudioPlayerInternalStateRebuffering;
}

-(void) audioPlayer:(AudioPlayer*)audioPlayer didEncounterError:(AudioPlayerErrorCode)errorCode
{
    CJAudioPlayerLog(@"didEncounterError: %@", NSStringFromAudioPlayerErrorCode(errorCode));
    [self playNext];
}

-(void) audioPlayer:(AudioPlayer*)audioPlayer didStartPlayingQueueItemId:(NSObject*)queueItemId
{
    CJAudioPlayerLog(@"didStartPlayingQueueItemId: %@", queueItemId);

    id <CJAudioPlayerQueueItem> item = [self itemForQueueID:queueItemId];

    CJAudioPlayerLog(@"%@", _queuedDataSource.queueID);
    CJAudioPlayerLog(@"%@", queueItemId);

    if (_queuedDataSource.queueID == queueItemId) {
        CJAudioPlayerLog(@"replacing _currentDataSource with _queuedDataSource", nil);
        _currentDataSource = _queuedDataSource;
        _queuedDataSource = nil;
    }

    // if this throws an exception, our logic is screwed up somewhere
    assert(_currentDataSource.queueID == queueItemId);
    assert(_currentDataSource.delegate);

    _currentQueuePosition = [_queue indexOfObject:item];
    CJAudioPlayerLog(@"set currentQueuePosition to %d", _currentQueuePosition);

    if (_queuedDataSource == nil) {
        [self queueItem:[self getNextItem]];
    }

    if ([self.delegate respondsToSelector:@selector(audioPlayer:didStartPlayingItem:isFullyCached:)])
        [self.delegate audioPlayer:self didStartPlayingItem:item isFullyCached:_currentDataSource.isFullyCached];
}

-(void) audioPlayer:(AudioPlayer*)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject*)queueItemId
{
    CJAudioPlayerLog(@"didFinishBufferingSourceWithQueueItemId: %@", queueItemId);
}

-(void) audioPlayer:(AudioPlayer*)audioPlayer didFinishPlayingQueueItemId:(NSObject*)queueItemId withReason:(AudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration
{
    CJAudioPlayerLog(@"didFinishPlayingQueueItemId: %@", queueItemId);
    CJAudioPlayerLog(@"currently playing queue item id %@", audioPlayer.currentlyPlayingQueueItemId);
    CJAudioPlayerLog(@"stopReason: %@", NSStringFromAudioPlayerStopReason(stopReason)); // TODO: figure out why the stop reason isnt EOF

    if (_currentDataSource.queueID == queueItemId) {
        [_currentDataSource teardown];
        _currentDataSource = nil;
    }

    if (![self hasNextItem]) {
        if ([self.delegate respondsToSelector:@selector(audioPlayerDidFinishPlayingQueue:)]) {
            [self.delegate audioPlayerDidFinishPlayingQueue:self];
        }
    }
}

#pragma mark - CJHTTPCachedDataSourceInfoDelegate methods

- (void)dataSourceDidFinishDownloading:(CJHTTPCachedDataSource *)dataSource
{
    CJAudioPlayerLog(@"dataSourceDidFinishDownloading: %@", dataSource);
}

- (void)dataSourceWillStartReadingFromCache:(CJHTTPCachedDataSource *)dataSource
{
    CJAudioPlayerLog(@"dataSourceWillStartReadingFromCache: %@", dataSource);
}

- (void)dataSource:(CJHTTPCachedDataSource *)dataSource didUpdateDownloadProgressWithBytesDownloaded:(NSUInteger)bytesDownloaded bytesExpected:(NSUInteger)bytesExpected
{
    if (dataSource == _currentDataSource) {
        if ([self.delegate respondsToSelector:@selector(audioPlayer:currentItemDidUpdateDownloadProgressWithBytesDownloaded:bytesExpected:)]) {
            [self.delegate audioPlayer:self currentItemDidUpdateDownloadProgressWithBytesDownloaded:bytesDownloaded bytesExpected:bytesExpected];
        }
    }
}

@end
