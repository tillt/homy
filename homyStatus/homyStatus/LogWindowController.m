//
//  LogWindowController.m
//  homyStatus
//
//  Created by Till Toenshoff on 15.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import "LogWindowController.h"

NSString * const kLogPath = @"/usr/local/var/log/homy.log";

@interface LogWindowController ()
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (weak) IBOutlet NSTextView *textView;

@property (strong) dispatch_source_t fileSystemSource;
@property (strong) dispatch_io_t channel;
@property (assign) off_t offset;
@end

@implementation LogWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];

    [[self.window standardWindowButton:NSWindowZoomButton] setHidden:YES];
    [[self.window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];

    [self.textView setMinSize:NSMakeSize(0.0, self.textView.frame.size.height)];
    [self.textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [self.textView setVerticallyResizable:YES];
    [self.textView setHorizontallyResizable:YES];

    [[self.textView enclosingScrollView] setHasHorizontalScroller:YES];
    [self.textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self.textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[self.textView textContainer] setWidthTracksTextView:NO];
    self.textView.editable = NO;
}

- (void)closeWindow
{
    if (self.fileSystemSource) {
        // Cancel FS-watcher.
        dispatch_source_cancel(self.fileSystemSource);
        self.fileSystemSource = nil;
    }
    // Hide log window.
    [self.window orderOut:self];
    // Hide application icon.
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
    [self closeWindow];
    return NO;
}

- (void)setupFSWatcher:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];

    dispatch_queue_t observerQueue = dispatch_queue_create("filesystem-observer-queue", 0);
    int fd = open([url fileSystemRepresentation], O_EVTONLY);
    dispatch_source_vnode_flags_t eventMask = DISPATCH_VNODE_EXTEND;
    self.fileSystemSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd, eventMask, observerQueue);

    dispatch_source_set_event_handler(self.fileSystemSource, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadLog:kLogPath];
        });
    });

    dispatch_source_set_cancel_handler(self.fileSystemSource, ^{
        close(fd);
    });

    dispatch_resume(self.fileSystemSource);
}

- (void)loadLog:(NSString *)path
{
    [self.spinner startAnimation:self];
    
    if (self.channel == nil) {
        self.channel = dispatch_io_create_with_path(DISPATCH_IO_RANDOM,
                                                    [path UTF8String],
                                                    O_RDONLY,
                                                    0,
                                                    dispatch_get_main_queue(),
                                                    ^(int error){
                                                        // Cleanup code
                                                        if (error == 0) {
                                                            self.channel = nil;
                                                        }
                                                    });
    }
     
    // If the file channel could not be created, just abort.
    if (!self.channel)
        return;
     
    dispatch_io_read(self.channel, self.offset, SIZE_MAX, dispatch_get_main_queue(),
        ^(bool done, dispatch_data_t data, int error){
        [self.spinner stopAnimation:self];

        if (error) {
            NSLog(@"Error: %d", error);
            return;
        }

        dispatch_data_apply(data,
                            (dispatch_data_applier_t)^(dispatch_data_t region, size_t offset, const void *buffer, size_t size){
            
            NSString *log = [[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding];
            self.offset += size;
            NSDictionary *attributes = @{
                NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular],
                NSForegroundColorAttributeName: NSColor.textColor
            };
            NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString:log attributes:attributes];
            [self.textView.textStorage appendAttributedString:attrstr];
            [self.textView scrollRangeToVisible: NSMakeRange(self.textView.string.length, 0)];
            return true;  // Keep processing if there is more data.
        });

        [self setupFSWatcher:kLogPath];
    });
}

- (BOOL)isWindowVisible
{
    return [self.window isVisible];
}

- (void)showWindow
{
    // Show application icon.
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyRegular];
    // Show window.
    [self.window makeKeyAndOrderFront:self];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

    // Load log file.
    [self loadLog:kLogPath];
}

@end
