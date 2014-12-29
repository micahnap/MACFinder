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
@property (strong, nonatomic) Hosts *device;
@property (strong, nonatomic) NSMutableArray *hosts;
@property (strong, nonatomic) GBPing *ping;

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
    //sender.selected = !sender.selected;
    if (!self.hosts) {
        self.hosts = [NSMutableArray new];
    }
    
    [self.hosts removeAllObjects];
    
    self.ping = [GBPing new];
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
                [self populateArrayWithMACAndVendorInfoWithCompletion:^{
                    [self.tableView reloadData];
                }];
                
                [_ping stop];
                _ping = nil;
            }];
        }
        else {
            l(@"failed to start");
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

- (void)populateArrayWithMACAndVendorInfoWithCompletion:(void(^)(void))completionBlock{
    
    [self.hosts enumerateObjectsUsingBlock:^(Hosts *obj, NSUInteger idx, BOOL *stop){
        NSString *macAddress = [UIDevice ip2mac:(char *)[obj.ipAddress cStringUsingEncoding:NSUTF8StringEncoding]];
        obj.macAddress = macAddress ? macAddress : @"";
        
        if (![macAddress isEqualToString:@""]) {
            NSString *macURLAppend = [NSString stringWithFormat:@"%@%@", VENDORURL, obj.macAddress];
            
            AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
            manager.responseSerializer = [AFJSONResponseSerializer serializer];
            [manager GET:macURLAppend
              parameters:nil
                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                     
                     NSArray *responseDict = (NSArray *)responseObject;
                     NSDictionary *dict = responseDict[0];
                     obj.manufacturer = dict[@"company"];
                     
                     if (idx == [self.hosts count] -1) {
                         completionBlock();
                     }
                 }failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                     obj.manufacturer = @"";
                 }];
        }
    }];
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

    cell.hostMAC.text = host.macAddress;
    cell.hostName.text = host.ipAddress;
    cell.hostVendor.text = host.manufacturer;
    
    return cell;
}

#pragma mark - GBPing delegates
-(void)ping:(GBPing *)pinger didReceiveReplyWithSummary:(GBPingSummary *)summary {
    //l(@"REPLY>  %@", summary);

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
