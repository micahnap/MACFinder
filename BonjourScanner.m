//
//  BonjourScanner.m
//  Cammy
//
//  Created by Jimmy Lee on 8/08/2014.
//  Copyright (c) 2014 SELU. All rights reserved.
//

#import "BonjourScanner.h"
#import "UIDevice+Reachability.h"

@interface BonjourScanner ()

@property (strong, nonatomic) NSNetServiceBrowser *netServiceBrowser;
@property (strong, nonatomic) NSMutableArray *netServices;
@property (nonatomic) NSTimeInterval timeoutInterval;
@property (nonatomic, copy) void (^scanCompleteBlock)(BOOL finished);

@end

#pragma mark -

@implementation BonjourScanner

- (void)scan:(void (^)(BOOL finished))scanCompleteBlock
{
    if (self.netServiceBrowser) {
        [self.netServiceBrowser stop];
    }
    
    self.scanCompleteBlock = scanCompleteBlock;
    self.timeoutInterval = [[NSDate date] timeIntervalSince1970];

    self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    [self.netServiceBrowser setDelegate:self];
    [self.netServiceBrowser searchForServicesOfType:@"_http._tcp." inDomain:@""];
    self.netServices = [NSMutableArray array];
    
    NSTimeInterval scanStart = self.timeoutInterval;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        if (self.timeoutInterval == scanStart) {

            if (self.scanCompleteBlock) {
                self.scanCompleteBlock(NO);
                self.scanCompleteBlock = nil;
            }
        } else {
            NSLog(@"Bonjour Scanner didn't time out.");
        }
    });
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
    self.timeoutInterval = 0;

}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    self.timeoutInterval = 0;
    
    [_netServices addObject:aNetService]; // retain
    
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:10.0];
    
    if (!moreComing) {
        if (self.scanCompleteBlock) {
            self.scanCompleteBlock(YES);
            self.scanCompleteBlock = nil;
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    self.timeoutInterval = 0;
    if (self.scanCompleteBlock) {
        self.scanCompleteBlock(NO);
        self.scanCompleteBlock = nil;
    }
}

//- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
//    DScanLog(@"didRemoveDomain:%@", domainString);
//}
//
//- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
//    DScanLog(@"didRemoveService");
//}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    NSLog(@"netServiceBrowserDidStopSearch");
    self.timeoutInterval = 0;
    if (self.scanCompleteBlock) {
        self.scanCompleteBlock(NO);
        self.scanCompleteBlock = nil;
    }
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSLog(@"netServiceDidResolveAddress: %@", sender);
    NSLog(@"type - %@", sender.type);
    
    JLHTTPDevice *device = [JLHTTPDevice new];
    
    for (NSData *data in sender.addresses) {
        device.IPAddress = [UIDevice addressFromData:data];
        break;
    }
    
    NSLog(@"Dictionary: %@", [NSNetService dictionaryFromTXTRecordData:sender.TXTRecordData]);
    
    [sender stop];
    [_netServices removeObject:sender]; // release
    
    device.port = [NSString stringWithFormat:@"%ld", (long)sender.port];
    device.IPAddress = device.IPAddress;
    
    if (sender.port == 80) {
        device.url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", device.IPAddress]];

    }
    else {
        device.url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%@", device.IPAddress, device.port]];
    }
    
    device.serviceDescription = sender.name;
    device.hostname = sender.name;
    
    if (self.foundDevice) {
        self.foundDevice(device);
    }
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"netService:didNotResolve: %@", errorDict);
}

- (void)netServiceDidStop:(NSNetService *)sender {
    NSLog(@"netServiceDidStop");
}

- (void)stop {}

@end
