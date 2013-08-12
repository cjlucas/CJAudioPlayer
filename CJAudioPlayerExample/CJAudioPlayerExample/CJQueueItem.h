//
//  CJQueueItem.h
//  CJAudioPlayerExample
//
//  Created by Chris Lucas on 8/7/13.
//  Copyright (c) 2013 Chris Lucas. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CJAudioPlayer.h"

@interface CJQueueItem : NSObject <CJAudioPlayerQueueItem>

@property NSURL *httpURL;
@property NSURL *cacheURL;
@property id queueID;

@end
