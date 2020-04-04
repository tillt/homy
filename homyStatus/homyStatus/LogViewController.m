//
//  LogWindowController.m
//  homyStatus
//
//  Created by Till Toenshoff on 15.03.20.
//  Copyright © 2020 Till Toenshoff. All rights reserved.
//

#import "LogViewController.h"

NSString * const kLogPath = @"/usr/local/var/log/homy.log";

@interface LogViewController ()
@property (weak) IBOutlet NSTextView *textView;

@property (strong) dispatch_source_t fileSystemSource;
@property (strong) dispatch_io_t channel;
@property (assign) off_t offset;
@property (strong) NSMutableString *log;

@end

@implementation LogViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.log = [NSMutableString string];

    self.offset = 0LL;
    [self loadLog:kLogPath];
}

// Installs a filesystem watcher that keeps an eye on that log file.
- (void)setupFSWatcher:(NSString *)path
{
    if (self.fileSystemSource != nil) {
        // One watcher is enough.
        return;
    }

    NSURL *url = [NSURL fileURLWithPath:path];

    dispatch_queue_t observerQueue = dispatch_queue_create("filesystem-observer-queue", 0);

    // Open a file-descriptor for event notifications only.
    int fd = open([url fileSystemRepresentation], O_EVTONLY);

    // Trigger when the filesystem object changed in size.
    dispatch_source_vnode_flags_t eventMask = DISPATCH_VNODE_EXTEND;

    self.fileSystemSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd, eventMask, observerQueue);
    
    dispatch_source_set_event_handler(self.fileSystemSource, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_source_vnode_flags_t flags = dispatch_source_get_data(self.fileSystemSource);//obtain flags
            NSLog(@"%lu",flags);

          
            NSLog(@"FS triggered\n");
            // Load moar!
            [self loadLog:kLogPath];
        });
    });

    dispatch_source_set_cancel_handler(self.fileSystemSource, ^{
        close(fd);
    });

    dispatch_resume(self.fileSystemSource);
}

// Reads that log file asynchronously and posts results back into the logging
// window on the main dispatch queue. When done, installs a file-system watcher
// that allows further updates when the file changed in size.
- (void)loadLog:(NSString *)path
{
    if (self.channel == nil) {
        self.channel = dispatch_io_create_with_path(
            DISPATCH_IO_RANDOM,
            [path UTF8String],
            O_RDONLY,
            0,
            dispatch_get_main_queue(),
            ^(int error){
                // Cleanup code.
                if (error == 0) {
                    NSLog(@"Error: %d", error);
                    self.channel = nil;
                }
            });
    }
     
    if (self.channel == nil)
    {
        return;
    }
    
    [self.log setString:@""];

    dispatch_io_read(self.channel, 0LL, SIZE_MAX, dispatch_get_main_queue(),
        ^(bool done, dispatch_data_t data, int error){
        if (error) {
            NSLog(@"Error: %d", error);
            return;
        }
        
        dispatch_data_apply(data,
                            (dispatch_data_applier_t)^(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
            NSString *fragment = [[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding];

            [self.log appendString:fragment];

            self.offset += size;
            
            NSLog(@"offset: %ld", offset);
            NSLog(@"size: %ld", size);
            NSLog(@"new offset after this read: %lld", self.offset);


            return true;  // Keep processing if there is more data.
        });
        
        if (done) {
            NSLog(@"done with offset: %lld", self.offset);

            NSDictionary *attributes = @{
                NSFontAttributeName: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightLight],
                NSForegroundColorAttributeName: NSColor.textColor
            };
            NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString:self.log attributes:attributes];
            [self.textView.textStorage setAttributedString:attrstr];
            [self.textView scrollRangeToVisible: NSMakeRange(self.textView.string.length, 0)];

            [self setupFSWatcher:path];
        }
    });
}

@end
