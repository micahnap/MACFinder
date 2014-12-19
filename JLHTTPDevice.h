//
//  JLHTTPDevice.h
//  Cammy
//
//  Created by Jimmy Lee on 9/01/2014.
//  Copyright (c) 2014 SELU. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JLHTTPDevice : NSObject

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *serviceDescription;
@property (strong, nonatomic) NSString *MACAddress;
@property (strong, nonatomic) NSString *IPAddress;
@property (strong, nonatomic) NSString *port;
@property (strong, nonatomic) NSString *hostname;
@property (strong, nonatomic) NSString *manufacturer;
@property (strong, nonatomic) NSString *model;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;
@property (nonatomic) BOOL knownDevice;

- (NSString *)nonNilMACAddress;
- (NSString *)nonNilManufacturer;
- (NSString *)nonNilModel;
- (NSString *)nonNilHostname;

@end
