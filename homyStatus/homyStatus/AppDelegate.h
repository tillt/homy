//
//  AppDelegate.h
//  homyStatus
//
//  Created by Till Toenshoff on 05.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (nonatomic, strong) NSString *status;

@end

