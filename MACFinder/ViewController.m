//
//  ViewController.m
//  MACFinder
//
//  Created by Micah Napier on 17/12/2014.
//  Copyright (c) 2014 Micah Napier. All rights reserved.
//

#import "ViewController.h"
#import "BonjourScanner.h"
#import "UIDevice+Reachability.h"
#import "CDZPinger.h"

@interface ViewController () <CDZPingerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnScan;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (strong, nonatomic) BonjourScanner *bonjourScanner;
@property (strong, nonatomic) JLHTTPDevice *device;
@property (strong, nonatomic) NSMutableArray *pingers;
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

- (IBAction)startStopScan:(id)sender {

    NSString *myLocalIPAddress = [[UIDevice currentDevice] getIPAddress:true];
    NSLog(@"myLocalIPAddress: %@", myLocalIPAddress);

//    CDZPinger *pinger = [[CDZPinger alloc] initWithHost:myLocalIPAddress];
//    [self.pingers addObject:pinger];
//    pinger.delegate = self;
//    [pinger startPinging];
    
//    if (!self.bonjourScanner) {
//        self.bonjourScanner = [BonjourScanner new];
//        __unsafe_unretained typeof(self) weakSelf = self;
//        self.bonjourScanner.foundDevice = ^(JLHTTPDevice *device) {
//            [weakSelf findMACAddressAndManufacturer:device];
//            NSLog(@"Bonjour found: %@ %@ %@", device.hostname, device.MACAddress, device.IPAddress);
//        };
//    }
//    
    
//    [self.bonjourScanner scan:^(BOOL finished){
//        NSLog(@"bonjourScanner complete");
//    }];
}

- (void)findMACAddressAndManufacturer:(JLHTTPDevice *)device {
    if (device == nil) {
        NSLog(@"Tried to find MAC address for nil device");
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block int i = 0;
        while (i < 50) {
            if (!device.MACAddress) {
                if (device.IPAddress != nil) {
                    device.MACAddress = [UIDevice ip2mac:(char *)[device.IPAddress cStringUsingEncoding:NSUTF8StringEncoding]];
                }
            }
            if (device.MACAddress) {
                //device.manufacturer = [self getManufacturer:device.MACAddress];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    NSLog(@"Found:HOST  %@ IPAddress %@, MAC %@", device.hostname, device.IPAddress, device.MACAddress);
                    //[self fireCallbackForDevice:device];
                });
                break;
            }
            else if (device.IPAddress) {
                NSLog(@"Failed to get MAC, try pinging: %@", device.IPAddress);
                CDZPinger *pinger = [[CDZPinger alloc] initWithHost:device.IPAddress];
                [self.pingers addObject:pinger];
                pinger.delegate = self;
                [pinger startPinging];
            }
            i++;
            [NSThread sleepForTimeInterval:0.2f];
        }
//        if (!device.MACAddress) {
//            if (self.couldNotFindMacBlock) {
//                self.couldNotFindMacBlock();
//            }
//            CLS_LOG(@"Failed to find MAC for device:%@ with ip address:%@", device.hostname, device.IPAddress);
//        }
    });
    
}

#pragma mark CDZPingerDelegate

- (void)pinger:(CDZPinger *)pinger didUpdateWithAverageSeconds:(NSTimeInterval)seconds
{
    NSLog(@"Received ping; average time %.f ms", seconds*1000);
}

@end
