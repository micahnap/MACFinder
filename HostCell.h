//
//  HostCell.h
//  MACFinder
//
//  Created by Micah Napier on 29/12/2014.
//  Copyright (c) 2014 Micah Napier. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HostCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *hostName;
@property (weak, nonatomic) IBOutlet UILabel *hostMAC;
@property (weak, nonatomic) IBOutlet UILabel *hostVendor;
@end
