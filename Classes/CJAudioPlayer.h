//
//  CJDataSourceQueueManager.h
//  Audjustable
//
//  Created by Chris Lucas on 7/29/13.
//
//

#import <Foundation/Foundation.h>
#import "DataSource.h"
#import "AudioPlayer.h"
#import "CJHTTPCachedDataSource.h"

#define CJAudioPlayerDebug 0

@protocol CJAudioPlayerQueueItem <NSObject>
@required
- (NSURL *)httpURL;
- (id)queueID;
@optional
- (NSURL *)cacheURL; // if nil, a temporary file will be created and will be deleted when the item is done playing.
@end

@class CJAudioPlayer;

@protocol CJAudioPlayerDelegate <NSObject>
@optional
// download info
- (void)audioPlayerCurrentItemDidBeginDownloading:(CJAudioPlayer *)audioPlayer;
- (void)audioPlayer:(CJAudioPlayer *)audioPlayer currentItemDidUpdateDownloadProgressWithBytesDownloaded:(NSUInteger)bytesDownloaded bytesExpected:(NSUInteger)bytesExpected;
- (void)audioPlayerCurrentItemDidFinishDownloading:(CJAudioPlayer *)audioPlayer;
- (void)audioPlayerDidBeginBuffering:(CJAudioPlayer *)audioPlayer;
- (void)audioPlayerDidFinishBuffering:(CJAudioPlayer *)audioPlayer;

// playback info
- (void)audioPlayer:(CJAudioPlayer *)audioPlayer didStartPlayingItem:(id <CJAudioPlayerQueueItem>)item isFullyCached:(BOOL)fullyCached;
- (void)audioPlayer:(CJAudioPlayer *)audioPlayer didPauseItem:(id <CJAudioPlayerQueueItem>)item;
- (void)audioPlayer:(CJAudioPlayer *)audioPlayer didFinishPlayingItem:(id <CJAudioPlayerQueueItem>)item;
- (void)audioPlayerDidFinishPlayingQueue:(CJAudioPlayer *)audioPlayer;
@end

@interface CJAudioPlayer : NSObject <AudioPlayerDelegate, CJHTTPCachedDataSourceInfoDelegate> {
    AudioPlayer *_player;
    NSUInteger _currentQueuePosition; // set in audioPlayer:didStartPlayingQueueItemId:

    NSMutableArray *_items;
    NSMutableArray *_queue;

    CJHTTPCachedDataSource *_currentDataSource;
    CJHTTPCachedDataSource *_queuedDataSource;
}

// queue management
- (NSArray *)queue;
- (void)addItem:(id <CJAudioPlayerQueueItem>)item; // if shuffle is enabled, queue will be reshuffled at this point
- (void)resetItems;
- (BOOL)hasNextItem;
- (BOOL)hasPreviousItem;

// controls
- (void)play;
- (void)playItem:(id <CJAudioPlayerQueueItem>)item; // item must be in queue
- (void)pause;
- (void)togglePlayPause; // convenience
- (void)playNext;
- (void)playPrevious;

@property (readonly, copy) NSArray *items;
@property (readonly, copy) NSArray *queue;
@property (readonly) id <CJAudioPlayerQueueItem> currentItem;

@property (getter=isShuffleModeEnabled) BOOL shuffleModeEnabled;
@property (getter=isContinuousModeEnabled) BOOL continuousModeEnabled;

@property id <CJAudioPlayerDelegate> delegate;

@property (readonly) double progress; // in seconds
@property (readonly) double duration; // in seconds
@end
