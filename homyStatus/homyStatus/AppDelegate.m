//
//  AppDelegate.m
//  homyStatus
//
//  Created by Till Toenshoff on 05.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedStatusUpdate:) name:@"TTHomyStatusUpdate" object:nil];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self requestStatus];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)receivedStatusUpdate:(NSNotification *)aNotification
{
    NSLog(@"Received status update notification");
    [self requestStatus];
}

- (void)requestStatus
{
   NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
   NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

   NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8998"];
   NSURLRequest *req = [NSURLRequest requestWithURL:url];

   NSURLSessionDataTask *dataTask = [urlSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
       if (error) {
           dispatch_async(dispatch_get_main_queue(), ^{
               NSLog(@"Error: %@", error);
               self.status = @"Error";
               [self updateStatusItemMenu];
           });
       } else {
           dispatch_async(dispatch_get_main_queue(), ^{
               NSString *location = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
               self.status = [NSString stringWithFormat:@"Location: %@", location];
               [self updateStatusItemMenu];
           });
       }
   }];
   [dataTask resume];
}

- (void)updateStatusItemMenu
{
    NSImage *image = [NSImage imageNamed:@"StatusImageHome"];
    [image setTemplate:true];
    self.statusItem.button.image = image;

    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:self.status action:@selector(statusItemActivated:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    
    self.statusItem.menu = menu;
}

#pragma mark - Menu actions

- (void)statusItemActivated:(id)sender
{
    // Shall we do something here?
}

@end
