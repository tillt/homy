//
//  LogWindowController.h
//  homyStatus
//
//  Created by Till Toenshoff on 15.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface LogWindowController : NSWindowController
- (void)showWindow;
- (BOOL)isWindowVisible;
@end

NS_ASSUME_NONNULL_END
