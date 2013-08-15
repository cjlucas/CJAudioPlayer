//
//  CJQueueTableViewController.m
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/11/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import "CJQueueTableViewController.h"

#import "CJAppDelegate.h"

@interface CJQueueTableViewController ()

- (id <CJAudioPlayerQueueItem>)queueItemForIndexPath:(NSIndexPath *)indexPath;

@property (readonly) CJAudioPlayer *audioPlayer;
@end

@implementation CJQueueTableViewController

- (CJAudioPlayer *)audioPlayer
{
    return ((CJAppDelegate *)[UIApplication sharedApplication].delegate).audioPlayer;
}

- (id <CJAudioPlayerQueueItem>)queueItemForIndexPath:(NSIndexPath *)indexPath
{
    return [self.audioPlayer.queue objectAtIndex:[indexPath indexAtPosition:1]];
}

- (IBAction)closeButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.audioPlayer.queue.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    id <CJAudioPlayerQueueItem> item = [self queueItemForIndexPath:indexPath];

    // highlight currently playing item
    if (item == self.audioPlayer.currentItem) {
        cell.textLabel.textColor = [cell tintColor];
    }

    cell.textLabel.text = [item httpURL].absoluteString;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id <CJAudioPlayerQueueItem> item = [self queueItemForIndexPath:indexPath];

    [self.audioPlayer playItem:item];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
