//
//  CJAudioPlayerViewController.m
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/7/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import "CJAudioPlayerViewController.h"

#import "CJAppDelegate.h"
#import "CJQueueItem.h"

#import <MediaPlayer/MediaPlayer.h>

@interface CJAudioPlayerViewController ()
- (void)updateInterfaceWithItem:(CJQueueItem *)item;
- (void)updatePlaybackProgressLabel:(NSTimer *)timer;
- (void)resetInterface;

- (void)emptyCache;
- (CJQueueItem *)queueItemForURLString:(NSString *)urlString;

@property (readonly) NSURL *cacheDirectory;
@property (readonly) CJAppDelegate *appDelegate;
@property (readonly) CJAudioPlayer *audioPlayer; // audio player from app delegate;
@property NSTimer *updatePlaybackProgressTimer;
@end

@implementation CJAudioPlayerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:self.volumeViewContainer.bounds];
    [self.volumeViewContainer addSubview:volumeView];

    NSURL *sourcesFile = [[NSBundle mainBundle] URLForResource:@"sources" withExtension:@"txt"];
    NSArray *sources = [[NSString stringWithContentsOfURL:sourcesFile encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"];
    for (NSString *urlString in sources) {
        if (![@"#" isEqualToString:[urlString substringToIndex:1]]) // ignore commented out sources
            [self.audioPlayer addItem:[self queueItemForURLString:urlString]];
    }

    [self resetInterface];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    //[self becomeFirstResponder];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

    self.audioPlayer.delegate = self;
    self.updatePlaybackProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updatePlaybackProgressLabel:) userInfo:nil repeats:YES];

    [self updateInterfaceWithItem:self.audioPlayer.currentItem];
}

- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"viewDidDisappear");

    [self resignFirstResponder];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];

    self.audioPlayer.delegate = [self appDelegate];
    [self.updatePlaybackProgressTimer invalidate];

    [super viewDidDisappear:animated];
}

#pragma mark - UI Manipulation

- (void)updateInterfaceWithItem:(CJQueueItem *)item
{
    self.currentTrackLabel.text = item.httpURL.absoluteString;
    self.playPreviousButton.enabled = [self.audioPlayer hasPreviousItem];
    self.playNextButton.enabled = [self.audioPlayer hasNextItem];
}

- (void)resetInterface
{
    self.downloadProgressLabel.text = @"Download Progress";
    self.playbackProgressLabel.text = @"Playback Progress";
}

- (void)updatePlaybackProgressLabel:(NSTimer *)timer
{
    self.playbackProgressLabel.text = [NSString stringWithFormat:@"%f s / %f s", self.audioPlayer.progress, self.audioPlayer.duration];
}

#pragma mark - UI User Actions

- (IBAction)playPauseToggleButtonPressed:(id)sender {
    NSLog(@"playPauseToggleButtonPressed");

    [self.audioPlayer togglePlayPause];
    self.emptyCacheButton.enabled = NO;
}

- (IBAction)playPreviousButtonPressed:(id)sender {
    NSLog(@"playPreviousButtonPressed");
    [self resetInterface];
    [self.audioPlayer playPrevious];
}

- (IBAction)playNextButtonPressed:(id)sender {
    NSLog(@"playNextButtonPressed");
    [self resetInterface];
    [self.audioPlayer playNext];
}

- (IBAction)emptyCacheButtonPressed:(id)sender {
    NSLog(@"emptyCacheButtonPressed");
    [self emptyCache];
}

- (IBAction)toggleShuffleModeSwitchValueChanged:(id)sender {
    self.audioPlayer.shuffleModeEnabled = self.toggleShuffleModeSwitch.on;
}

- (IBAction)toggleContinuousModeSwitchValueChanged:(id)sender {
    self.audioPlayer.continuousModeEnabled = self.toggleContinuousModeSwitch.on;

    // update ui in case play prev/next buttons changed
    [self updateInterfaceWithItem:self.audioPlayer.currentItem];
}

#pragma mark - CJAudioPlayerDelegate methods

- (void)audioPlayer:(CJAudioPlayer *)audioPlayer didStartPlayingItem:(CJQueueItem *)item isFullyCached:(BOOL)fullyCached
{
    [self updateInterfaceWithItem:item];

    if (fullyCached) {
        self.downloadProgressLabel.text = @"Reading from cache";
    }

    [self.appDelegate audioPlayer:audioPlayer didStartPlayingItem:item isFullyCached:fullyCached];
}

- (void)audioPlayerDidBeginBuffering:(CJAudioPlayer *)audioPlayer
{
    NSLog(@"audioPlayerDidBeginBuffering");
}

- (void)audioPlayerDidFinishBuffering:(CJAudioPlayer *)audioPlayer
{
    NSLog(@"audioPlayerDidFinishBuffering");
}

- (void)audioPlayer:(CJAudioPlayer *)audioPlayer currentItemDidUpdateDownloadProgressWithBytesDownloaded:(NSUInteger)bytesDownloaded bytesExpected:(NSUInteger)bytesExpected
{
    __block float percentage = (bytesDownloaded * 100.0) / bytesExpected;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.downloadProgressLabel.text = [NSString stringWithFormat:@"%d B / %d B (%0.2f%% complete)", bytesDownloaded, bytesExpected, percentage];
    });
}


#pragma mark - Helpers

- (CJAppDelegate *)appDelegate
{
    return (CJAppDelegate *)[UIApplication sharedApplication].delegate;
}

- (CJAudioPlayer *)audioPlayer
{
    return self.appDelegate.audioPlayer;
}

- (CJQueueItem *)queueItemForURLString:(NSString *)urlString
{
    CJQueueItem *item = [[CJQueueItem alloc] init];

    item.httpURL = [NSURL URLWithString:urlString];
    item.queueID = item.httpURL;

    return item;
}

- (NSURL *)cacheDirectory
{
    return [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
}

- (void)emptyCache
{
    NSFileManager *fm = [NSFileManager defaultManager];

    NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:self.cacheDirectory includingPropertiesForKeys:nil options:0 errorHandler:nil];

    for (NSURL *fileURL in enumerator) {
        [fm removeItemAtURL:fileURL error:nil];
    }
}
@end
