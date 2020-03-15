//
//  AppDelegate.h
//  homyStatus
//
//  Created by Till Toenshoff on 05.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LogWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, LogWindowDelegate>

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (nonatomic, strong) NSString *status;

@property (nonatomic, strong) LogWindowController *logWindowController;
@end

