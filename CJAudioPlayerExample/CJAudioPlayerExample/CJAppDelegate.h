//
//  CJAppDelegate.h
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/7/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CJAudioPlayer.h"

@interface CJAppDelegate : UIResponder <UIApplicationDelegate, CJAudioPlayerDelegate>

- (void)updateNowPlayingInfo:(NSTimer *)timer;

@property (strong, nonatomic) UIWindow *window;
@property CJAudioPlayer *audioPlayer;
@property NSTimer *updateNowPlayingInfoTimer;

@end
