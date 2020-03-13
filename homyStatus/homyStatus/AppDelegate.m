//
//  AppDelegate.m
//  homyStatus
//
//  Created by Till Toenshoff on 05.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import "AppDelegate.h"

#import <CoreServices/CoreServices.h>

// Note that this is a bit of a half-assed approach in that
// for receiveing the current location from the daemon, we
// request it from an endpoint instead of directly reading
// it for the status file. On the other hand, for the log
// we do directly access it - forcing us to bbuild non-
// sandboxed.

NSString * const kStatusEndpoint = @"http://127.0.0.1:8998";
NSString * const kLogPath = @"/usr/local/var/log/homy.log";

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *logWindow;

@end

@implementation AppDelegate

#pragma mark - Notifications

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self.logWindow orderOut:self];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedStatusUpdate:) name:@"TTHomyStatusUpdate" object:nil];
    
    [self.textView setMinSize:NSMakeSize(0.0, self.textView.frame.size.height)];
    [self.textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [self.textView setVerticallyResizable:YES];
    [self.textView setHorizontallyResizable:YES];
   
    [[self.textView enclosingScrollView] setHasHorizontalScroller:YES];
    [self.textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self.textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[self.textView textContainer] setWidthTracksTextView:NO];
    self.textView.editable = NO;

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self requestStatus];
    
    [self setupFSWatcher:kLogPath];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)receivedStatusUpdate:(NSNotification *)aNotification
{
    NSLog(@"Received status update notification");
    [self requestStatus];
}

#pragma mark - Status

- (void)setStatus:(NSString *)newStatus
{
    _status = newStatus;
    [self updateStatusItemMenu];
    
    [self updateLog];
}

- (void)requestStatus
{
   NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
   NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

   NSURL *url = [NSURL URLWithString:kStatusEndpoint];
   NSURLRequest *req = [NSURLRequest requestWithURL:url];

   NSURLSessionDataTask *dataTask = [urlSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
       if (error) {
           dispatch_async(dispatch_get_main_queue(), ^{
               NSLog(@"Error: %@", error);
               self.status = @"Error";
           });
       } else {
           dispatch_async(dispatch_get_main_queue(), ^{
               NSString *location = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
               self.status = [NSString stringWithFormat:@"Location: %@", location];
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
    [menu addItemWithTitle:@"Show Logging Window" action:@selector(showLog:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    
    self.statusItem.menu = menu;
}

#pragma mark - Log

- (void)setupFSWatcher:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];

    dispatch_queue_t observerQueue = dispatch_queue_create("filesystem-observer-queue", 0);

    int fd = open([url fileSystemRepresentation], O_EVTONLY);

    dispatch_source_vnode_flags_t eventMask = DISPATCH_VNODE_EXTEND;

    dispatch_source_t fileSystemSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd, eventMask, observerQueue);

    dispatch_source_set_event_handler(fileSystemSource, ^{
        dispatch_source_vnode_flags_t eventSourceFlag = dispatch_source_get_data(fileSystemSource);
        NSLog(@"Change at %@ of type %lu", url, eventSourceFlag);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateLog];
        });

    });

    dispatch_source_set_cancel_handler(fileSystemSource, ^{
        close(fd);
    });

    dispatch_resume(fileSystemSource);
}

- (void)updateLog
{
    static unsigned long long offset = 0L;

    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:kLogPath];
    [file seekToFileOffset:offset];

    NSData *data = [file readDataToEndOfFile];
    
    offset += [data length];

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: NSColor.textColor
    };

    NSString *log = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString:log attributes:attributes];

    [self.textView.textStorage appendAttributedString:attrstr];
    
    [self.textView scrollRangeToVisible: NSMakeRange(self.textView.string.length, 0)];
}

#pragma mark - Menu actions

- (void)statusItemActivated:(id)sender
{
    // Shall we do something here?
}

- (void)showLog:(id)sender
{
    [self.logWindow makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
