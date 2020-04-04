//
//  AppDelegate.m
//  homyStatus
//
//  Created by Till Toenshoff on 05.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import "AppDelegate.h"

#import <CoreServices/CoreServices.h>

#import "LogViewController.h"

// Note that this is a bit of a half-assed approach in that
// for receiveing the current location from the daemon, we
// request it from an endpoint instead of directly reading
// it for the status file. On the other hand, for the log
// we do directly access it - forcing us to bbuild non-
// sandboxed.
// TODO(tillt): Find a way that allows us to remain sandboxed
// while accessing the log.

#pragma mark - Constants

NSString * const kStatusEndpoint = @"http://127.0.0.1:8998";

#pragma mark -

@interface AppDelegate ()

@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) NSMenu *statusMenu;

@end

@implementation AppDelegate

#pragma mark - Notifications

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    self.status = @"unknown";
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    self.statusItem.button.action = @selector(statusItemClicked:);
    [self.statusItem.button sendActionOn:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown];

    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"unknown" action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Show Log" action:@selector(showLog:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    menu.delegate = self;
    self.statusMenu = menu;

    // Hide application icon.
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self updateStatusItemImage];
    [self updateStatusItemMenu];

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedStatusUpdate:) name:@"TTHomyStatusUpdate" object:nil];

    [self requestStatus];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)receivedStatusUpdate:(NSNotification *)notification
{
    NSLog(@"Received status update notification");
    [self requestStatus];
}

#pragma mark - Status

- (void)setStatus:(NSString *)newStatus
{
    _status = newStatus;
    [self updateStatusItemImage];
    [self updateStatusItemMenu];
}

- (void)requestStatus
{
   NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
   NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

   NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:kStatusEndpoint]];

   NSURLSessionDataTask *dataTask = [urlSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
       if (error) {
           dispatch_async(dispatch_get_main_queue(), ^{
               NSLog(@"Error: %@", error);
               self.status = @"error";
           });
       } else {
           dispatch_async(dispatch_get_main_queue(), ^{
               NSString *location = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
               self.status = [location stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
           });
       }
   }];
   [dataTask resume];
}

- (void)updateStatusItemImage
{
    NSImage *image = [NSImage imageNamed:[NSString stringWithFormat:@"StatusImage_%@", self.status]];
    [image setTemplate:true];
    self.statusItem.button.image = image;
}

- (void)updateStatusItemMenu
{
    NSMenuItem *item = self.statusMenu.itemArray[0];
    item.title = [NSString stringWithFormat:@"Location: %@", self.status];
}

#pragma mark - Menu actions

- (void)showLog:(id)sender
{
    if (self.popover == nil) {
        self.popover = [[NSPopover alloc] init];
        self.popover.contentViewController = [[LogViewController alloc] initWithNibName:@"LogViewController" bundle:NULL];
        self.popover.contentSize = NSMakeSize(800.0f, 200.0f);
        self.popover.animates = YES;
        self.popover.appearance = [NSAppearance currentAppearance];
    }

    if (self.popover.isShown) {
        [self.popover performClose:sender];
    } else {
        [self.popover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSRectEdgeMinY];
        __block AppDelegate *blocksafeSelf = self;
        [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventTypeLeftMouseDown | NSEventTypeRightMouseDown handler:^(NSEvent *event) {
            [blocksafeSelf.popover performClose:nil];
        }];
    }
}

- (IBAction)showStatusMenu:(id)sender
{
    self.statusItem.menu = self.statusMenu;
    [self.statusItem.button performClick:nil];
}


- (void)statusItemClicked:(id)sender
{
    NSEvent *currentEvent = [NSApp currentEvent];

    if  ((([currentEvent modifierFlags] & NSEventModifierFlagControl) == NSEventModifierFlagControl) ||
         (([currentEvent modifierFlags] & NSEventModifierFlagCommand) == NSEventModifierFlagCommand) ||
         (([currentEvent modifierFlags] & NSEventMaskRightMouseUp) == NSEventMaskRightMouseUp) ||
         (([currentEvent modifierFlags] & NSEventMaskRightMouseDown) == NSEventMaskRightMouseDown) ||
         ([currentEvent type] == NSEventTypeRightMouseDown) ||
         ([currentEvent type] == NSEventTypeRightMouseUp))
    {
        [self showStatusMenu:self];
    }
    else
    {
        [self showLog:self];
    }
}

#pragma mark - Menu delegate

- (void)menuDidClose:(NSMenu *)menu
{
    self.statusItem.menu = nil;
    [self.statusItem.button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
    [self.statusItem.button setAction:@selector(statusItemClicked:)];
}

@end
