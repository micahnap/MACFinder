//
//  ViewController.m
//  MACFinder
//
//  Created by Micah Napier on 17/12/2014.
//  Copyright (c) 2014 Micah Napier. All rights reserved.
//

#import "ViewController.h"
#import "UIDevice+Reachability.h"
#import "GBPing.h"
#import <GBToolbox.h>
#import "Hosts.h"
#import <AFNetworking/AFNetworking.h>

#define BROADCAST_ADDRESS @"255.255.255.255"

@interface ViewController () <GBPingDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnScan;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (strong, nonatomic) Hosts *device;
@property (strong, nonatomic) NSMutableArray *hosts;
@property (strong, nonatomic) GBPing *ping;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startStopScan:(id)sender
{
    if (!self.hosts) {
        self.hosts = [NSMutableArray new];
    }
    
    [self.hosts removeAllObjects];
    
    self.ping = [[GBPing alloc] init];
    self.ping.host = BROADCAST_ADDRESS;
    self.ping.delegate = self;
    self.ping.timeout = 1;
    self.ping.pingPeriod = 0.9;
    
    [self.ping setupWithBlock:^(BOOL success, NSError *error) { //necessary to resolve hostname
        if (success) {
            //start pinging
            [self.ping startPinging];
            
            //stop it after 5 seconds
            [NSTimer scheduledTimerWithTimeInterval:5 repeats:NO withBlock:^{
                
                self.hosts = [[self arrayWithRemovedDuplicatesFromArray:[self.hosts copy]] mutableCopy];
                [self populateArrayWithMACAndVendorInfo];
                [_ping stop];
                _ping = nil;
            }];
        }
        else {
            NSLog(@"failed to start");
        }
    }];
}

-(NSArray *)arrayWithRemovedDuplicatesFromArray:(NSArray *)duplicateArray
{
    NSMutableSet *seenObjects = [NSMutableSet set];
    NSPredicate *dupPred = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind) {
        Hosts *hObj = (Hosts*)obj;
        BOOL seen = [seenObjects containsObject:hObj.ipAddress];
        if (!seen) {
            [seenObjects addObject:hObj.ipAddress];
        }
        return !seen;
    }];
    
    NSArray *yourHistoryArray = [duplicateArray filteredArrayUsingPredicate:dupPred];
    return yourHistoryArray;
}

- (void)populateArrayWithMACAndVendorInfo {
    [self.hosts enumerateObjectsUsingBlock:^(Hosts *obj, NSUInteger idx, BOOL *stop){
        NSString *macAddress = [UIDevice ip2mac:(char *)[obj.ipAddress cStringUsingEncoding:NSUTF8StringEncoding]];
        l(@"test: %@", macAddress);
    }];
}

//- (NSData *)dataFromHexString:(NSString *)string {
//    string = [string lowercaseString];
//    NSMutableData *data= [NSMutableData new];
//    unsigned char whole_byte;
//    char byte_chars[3] = {'\0','\0','\0'};
//    int i = 0;
//    NSUInteger length = string.length;
//    while (i < length-1) {
//        char c = [string characterAtIndex:i++];
//        if (c < '0' || (c > '9' && c < 'a') || c > 'f')
//            continue;
//        byte_chars[0] = c;
//        byte_chars[1] = [string characterAtIndex:i++];
//        whole_byte = strtol(byte_chars, NULL, 16);
//        [data appendBytes:&whole_byte length:1];
//    }
//    
//    return data;
//}
//
//- (NSString *)hexStringFromData:(NSData *)data
//{
//    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
//    
//    if (!dataBuffer)
//        return [NSString string];
//    
//    NSUInteger          dataLength  = [data length];
//    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
//    
//    for (int i = 0; i < dataLength; ++i)
//        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
//    
//    return [NSString stringWithString:hexString];
//}

-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary {
    //l(@"REPLY>  %@", summary);
    
//    l(@"macAddress: %@ for ip: %@", macAddress, summary.host);
//    NSLog(@"hostname: %@", [UIDevice getNameForIP:summary.host]);
    Hosts *host = [Hosts new];
    host.ipAddress = summary.host;
    
    if (![host.ipAddress containsSubstring:@"255"]) {
        [self.hosts addObject:host];
    }
}

-(void)ping:(GBPing *)pinger didReceiveUnexpectedReplyWithSummary:(GBPingSummary *)summary {
    l(@"BREPLY> %@", summary);
}

-(void)ping:(GBPing *)pinger didSendPingWithSummary:(GBPingSummary *)summary {
    l(@"SENT>   %@", summary);
}

-(void)ping:(GBPing *)pinger didTimeoutWithSummary:(GBPingSummary *)summary {
    l(@"TIMOUT> %@", summary);
}

-(void)ping:(GBPing *)pinger didFailWithError:(NSError *)error {
    l(@"FAIL>   %@", error);
}

-(void)ping:(GBPing *)pinger didFailToSendPingWithSummary:(GBPingSummary *)summary error:(NSError *)error {
    l(@"FSENT>  %@, %@", summary, error);
}

@end
