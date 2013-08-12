//
//  CJQueueTableViewController.h
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/11/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CJQueueTableViewController : UITableViewController
@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeButton;

- (IBAction)closeButtonPressed:(id)sender;
@end
