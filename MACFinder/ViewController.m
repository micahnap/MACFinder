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
#import "HostCell.h"

#define BROADCAST_ADDRESS @"255.255.255.255"
#define VENDORURL @"https://www.macvendorlookup.com/api/v2/"

@interface ViewController () <GBPingDelegate, UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnScan;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (strong, nonatomic) NSMutableArray *hosts;
@property (strong, nonatomic) NSMutableArray *deadHosts;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *lblFound;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[HostCell class] forCellReuseIdentifier:@"Cell"];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startStopScan:(UIButton *)sender
{
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        [self.activityIndicator startAnimating];
        [self.hosts removeAllObjects];
        GBPing *pinger;
        [self pingIPAdress:BROADCAST_ADDRESS forSeconds:5 withPinger:pinger];
    }
    else{
        [self.activityIndicator stopAnimating];
    }
}

-(void)pingIPAdress:(NSString *)ipAddress forSeconds:(int)secondsToPing withPinger:(GBPing *)pinger
{
    if (!self.hosts) {
        self.hosts = [NSMutableArray new];
    }
    
    if (!self.deadHosts) {
        self.deadHosts = [NSMutableArray new];
    }
    
    pinger = [[GBPing alloc] init];
    pinger.host = ipAddress;
    pinger.delegate = self;
    pinger.timeout = 1.0;
    pinger.pingPeriod = 0.9;
    
    [pinger setupWithBlock:^(BOOL success, NSError *error) { //necessary to resolve hostname
        if (success) {
            //start pinging
            [pinger startPinging];
            
            //stop it after 5 seconds
            [NSTimer scheduledTimerWithTimeInterval:5 repeats:NO withBlock:^{
                [self removedDuplicatesFromHostArrays];
                l(@"hosts: %@", self.hosts);
                l(@"dead hosts: %@", self.deadHosts);
                [pinger stop];
                if ([self.deadHosts count] > 0) {
                    [self pingDeadHosts];
                    [self.activityIndicator stopAnimating];
                    self.btnScan.selected = FALSE;
                }
                self.lblFound.hidden = false;
                self.lblFound.text = [NSString stringWithFormat:@"Found %lu devices", (unsigned long)[self.hosts count]];
                [self.tableView reloadData];
            }];
        }
        else {
            NSLog(@"failed to start");
        }
    }];}

-(void)removedDuplicatesFromHostArrays
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
    
    NSArray *newArray = [self.hosts filteredArrayUsingPredicate:dupPred];
    self.hosts = [newArray mutableCopy];
    newArray = [self.deadHosts filteredArrayUsingPredicate:dupPred];
    self.deadHosts = [newArray mutableCopy];
}

//- (void)populateArrayWithMACAndVendorInfoWithCompletion:(void(^)(void))completionBlock{
//    
//    [self.hosts enumerateObjectsUsingBlock:^(Hosts *obj, NSUInteger idx, BOOL *stop){
//        
//        NSString *macAddress = [UIDevice ip2mac:(char *)[obj.ipAddress cStringUsingEncoding:NSUTF8StringEncoding]];
//        obj.macAddress = macAddress ? macAddress : @"";
//        
//        if (![macAddress isEqualToString:@""]) {
//            NSString *macURLAppend = [NSString stringWithFormat:@"%@%@", VENDORURL, obj.macAddress];
//            
//            AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
//            manager.responseSerializer = [AFJSONResponseSerializer serializer];
//            [manager GET:macURLAppend
//              parameters:nil
//                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
//                     
//                     NSArray *responseDict = (NSArray *)responseObject;
//                     NSDictionary *dict = responseDict[0];
//                     obj.manufacturer = dict[@"company"];
//                     
//                     l(@"IDX: %lu and count: %lu", (unsigned long)idx, (unsigned long)[self.hosts count]);
//                     if (idx == [self.hosts count] -1) {
//                         completionBlock();
//                     }
//                 }failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//                     obj.manufacturer = @"";
//                     
//                     if (idx == [self.hosts count] -1) {
//                         completionBlock();
//                     }
//                 }];
//        }
//    }];
//}


- (void)getVendorInfoForMAC:(NSString *)macAddress completionBlock:(void (^)(BOOL succeeded, NSString *vendor))completionBlock
{
    NSString *macURLAppend = [NSString stringWithFormat:@"%@%@", VENDORURL, macAddress];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:macURLAppend]];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if ( !error )
                               {
                                   NSArray *responseDict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                                   NSDictionary *dict = responseDict[0];
                                   NSString *vendor = dict[@"company"];

                                   completionBlock(YES,vendor);
                               } else{
                                   completionBlock(NO,nil);
                               }
                           }];
}

-(void)pingDeadHosts
{
    [self.deadHosts enumerateObjectsUsingBlock:^(Hosts *obj, NSUInteger idx, BOOL *stop){
 
        GBPing *pinger;

        [self pingIPAdress:obj.ipAddress forSeconds:5 withPinger:pinger];
    }];
    
    [self.deadHosts removeAllObjects];
}

#pragma mark - TableView DataSource
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 69;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.hosts ? [self.hosts count] : 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    HostCell *cell = (HostCell *) [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    Hosts *host = self.hosts[indexPath.row];
    
    NSArray* topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"HostCell" owner:self options:nil];
    
    for (id currentObject in topLevelObjects)
    {
        if ([currentObject isKindOfClass:[UITableViewCell class]])
        {
            cell = (HostCell *)currentObject;
            break;
        }
    }
    
    if (host.manufacturer) {
        cell.hostVendor.text = host.manufacturer;
    }
    
    else{
        [self getVendorInfoForMAC:host.macAddress completionBlock:^(BOOL succeeded, NSString *vendor) {
            
            if (succeeded) {
                cell.hostVendor.text = vendor;
                host.manufacturer =  vendor;
            }
            else
            {
                cell.hostVendor.text = @"N/A";
            }
            
        }];
    }

    cell.hostMAC.text = host.macAddress;
    cell.hostName.text = host.ipAddress;
    
    return cell;
}

#pragma mark - GBPing delegates
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary {
    l(@"REPLY>  %@", summary);
    
    Hosts *host = [Hosts new];
    host.ipAddress = summary.host;
    NSString *macAddress = [UIDevice ip2mac:(char *)[summary.host cStringUsingEncoding:NSUTF8StringEncoding]];
    
    if (macAddress) {
        if (![host.ipAddress containsSubstring:@"255"]) {
            host.macAddress = macAddress;
            [self.hosts addObject:host];
        }
    }
    
    else{
        if (![host.ipAddress containsSubstring:@"255"]) {
            [self.deadHosts addObject:host];
        }
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
