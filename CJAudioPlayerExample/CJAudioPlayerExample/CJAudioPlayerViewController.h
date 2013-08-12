//
//  CJAudioPlayerViewController.h
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/7/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CJAudioPlayer.h"

@interface CJAudioPlayerViewController : UIViewController <CJAudioPlayerDelegate>
// Outlets
@property (weak, nonatomic) IBOutlet UIButton *emptyCacheButton;
@property (weak, nonatomic) IBOutlet UISwitch *toggleShuffleModeSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *toggleContinuousModeSwitch;

@property (weak, nonatomic) IBOutlet UILabel *currentTrackLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadProgressLabel;
@property (weak, nonatomic) IBOutlet UILabel *playbackProgressLabel;

@property (weak, nonatomic) IBOutlet UIButton *playPauseToggleButton;
@property (weak, nonatomic) IBOutlet UIButton *playNextButton;
@property (weak, nonatomic) IBOutlet UIButton *playPreviousButton;

@property (weak, nonatomic) IBOutlet UIView *volumeViewContainer;

// Actions
- (IBAction)playPauseToggleButtonPressed:(id)sender;
- (IBAction)playPreviousButtonPressed:(id)sender;
- (IBAction)playNextButtonPressed:(id)sender;
- (IBAction)emptyCacheButtonPressed:(id)sender;
- (IBAction)toggleShuffleModeSwitchValueChanged:(id)sender;
- (IBAction)toggleContinuousModeSwitchValueChanged:(id)sender;

@end
