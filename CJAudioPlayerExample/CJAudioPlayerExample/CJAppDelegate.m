//
//  CJAppDelegate.m
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/7/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import "CJAppDelegate.h"

#import <MediaPlayer/MediaPlayer.h>

@implementation CJAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    self.audioPlayer = [[CJAudioPlayer alloc] init];
    self.audioPlayer.delegate = self;

    self.updateNowPlayingInfoTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateNowPlayingInfo:) userInfo:nil repeats:YES];

    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    __block UIBackgroundTaskIdentifier backgroundTask;
    backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
        backgroundTask = UIBackgroundTaskInvalid;
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)audioPlayer:(CJAudioPlayer *)audioPlayer didStartPlayingItem:(id<CJAudioPlayerQueueItem>)item isFullyCached:(BOOL)fullyCached
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{MPMediaItemPropertyTitle : [self.audioPlayer.currentItem httpURL].absoluteString,
                                                                  MPMediaItemPropertyPlaybackDuration : [NSNumber numberWithFloat:self.audioPlayer.duration],
                                                                  MPNowPlayingInfoPropertyElapsedPlaybackTime : [NSNumber numberWithFloat:self.audioPlayer.progress],
                                                                  };
    });
}

- (void)updateNowPlayingInfo:(NSTimer *)timer
{
//    if (!self.audioPlayer.currentItem) {
//        return;
//    }
//
//    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{MPMediaItemPropertyTitle : [self.audioPlayer.currentItem httpURL].absoluteString,
//                                                              MPMediaItemPropertyPlaybackDuration : [NSNumber numberWithFloat:self.audioPlayer.duration],
//                                                              MPNowPlayingInfoPropertyElapsedPlaybackTime : [NSNumber numberWithFloat:self.audioPlayer.progress],
//                                                              };

}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    NSLog(@"audio player: %@", event);
    switch(event.subtype) {
        case UIEventSubtypeRemoteControlTogglePlayPause:
            [self.audioPlayer togglePlayPause];
            break;

        case UIEventSubtypeRemoteControlPlay:
            [self.audioPlayer play];
            break;

        case UIEventSubtypeRemoteControlPause:
            [self.audioPlayer pause];
            break;

        case UIEventSubtypeRemoteControlNextTrack:
            [self.audioPlayer playNext];
            break;

        case UIEventSubtypeRemoteControlPreviousTrack:
            [self.audioPlayer playPrevious];
            break;

        default:
            break;
    }
}

@end
