//
//  Hosts.h
//  MACFinder
//
//  Created by Micah Napier on 24/12/2014.
//  Copyright (c) 2014 Micah Napier. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Hosts : NSObject


@property (strong, nonatomic) NSString *macAddress;
@property (strong, nonatomic) NSString *ipAddress;
@property (strong, nonatomic) NSString *hostname;
@property (strong, nonatomic) NSString *manufacturer;

@end
