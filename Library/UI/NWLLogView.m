//
//  NWLLogView.m
//  NWLogging
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWLLogView.h"
#import "NWLTools.h"

@implementation NWLLogView {
    NSMutableString *buffer;
    BOOL waitingToPrint;
    dispatch_queue_t serial;
}

@synthesize maxLogSize;

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    if (!serial) {
        serial = dispatch_queue_create("NWLLogViewController-append", DISPATCH_QUEUE_SERIAL);
        maxLogSize = 100 * 1000; // 100 KB
        buffer = [[NSMutableString alloc] init];

#if TARGET_OS_IPHONE
        self.backgroundColor = UIColor.blackColor;
        self.textColor = UIColor.whiteColor;
        self.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:10];
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        if ([self respondsToSelector:@selector(setSpellCheckingType:)]) self.spellCheckingType = UITextSpellCheckingTypeNo;
#else // TARGET_OS_IPHONE
        self.backgroundColor = NSColor.blackColor;
        self.textColor = NSColor.whiteColor;
        self.font = [NSFont fontWithName:@"Courier" size:10];
#endif // TARGET_OS_IPHONE
        self.editable = NO;
    }
}


#pragma mark - Printing

- (void)printWithTag:(NSString *)tag lib:(NSString *)lib file:(NSString *)file line:(NSUInteger)line function:(NSString *)function date:(NSDate *)date message:(NSString *)message
{
    NSString *text = [NWLTools formatTag:tag lib:lib file:file line:line function:function date:date message:message];
    [self safeAppendAndFollowText:text];
}

- (NSString *)printerName
{
    return @"log-view";
}


#pragma mark - Appending

- (void)safeAppendAndFollowText:(NSString *)text
{
    dispatch_async(serial, ^{
        if (waitingToPrint) {
            [buffer appendString:text];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self appendAndFollowText:text];
            });
            waitingToPrint = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .2 * NSEC_PER_SEC), serial, ^(void){
                NSString *b = buffer;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self appendAndFollowText:b];
                });
                buffer = [[NSMutableString alloc] init];
                waitingToPrint = NO;
            });
        }
    });
}

- (void)appendAndScrollText:(NSString *)text
{
    [self append:text];
    [self scrollDown];
}

- (void)appendAndFollowText:(NSString *)text
{
    BOOL follow = [self isScrollAtEnd];
    [self append:text];
    if (follow) {
        [self scrollDown];
    }
}

- (void)append:(NSString *)string
{
#if TARGET_OS_IPHONE
    NSString *text = self.text;
#else // TARGET_OS_IPHONE
    NSString *text = self.string;
#endif // TARGET_OS_IPHONE
    if (string) {
        text = [text stringByAppendingString:string];
        if (maxLogSize && text.length > maxLogSize) {
            NSUInteger index = text.length - maxLogSize;
            NSRange r = [text rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet options:0 range:NSMakeRange(index, maxLogSize)];
            if (r.length) {
                index = r.location;
            }
            text = [@"..." stringByAppendingString:[text substringFromIndex:index]];
        }
    }
#if TARGET_OS_IPHONE
    self.text = text;
#else // TARGET_OS_IPHONE
    self.string = text;
#endif // TARGET_OS_IPHONE
}


#pragma mark - Scrolling

- (void)scrollDown
{
    [self performSelector:@selector(scrollDownNow) withObject:nil afterDelay:.1];
}

- (void)scrollDownNow
{
#if TARGET_OS_IPHONE
    if (self.text.length) {
        NSRange bottom = NSMakeRange(self.text.length - 1, 1);
        [self scrollRangeToVisible:bottom];
    }
#else // TARGET_OS_IPHONE
    [self scrollToEndOfDocument:nil];
#endif // TARGET_OS_IPHONE
}

- (BOOL)isScrollAtEnd
{
#if TARGET_OS_IPHONE
    NSUInteger offset = self.contentOffset.y + self.bounds.size.height;
    NSUInteger size = self.contentSize.height;
    BOOL result = offset >= size - 50;
    return result;
#else // TARGET_OS_IPHONE
    return YES;
#endif // TARGET_OS_IPHONE
}

@end
