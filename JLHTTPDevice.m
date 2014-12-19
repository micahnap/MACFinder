//
//  JLHTTPDevice.m
//  Cammy
//
//  Created by Jimmy Lee on 9/01/2014.
//  Copyright (c) 2014 SELU. All rights reserved.
//

#import "JLHTTPDevice.h"

@implementation JLHTTPDevice

- (id)init {
    self = [super init];
    if (self) {
        self.knownDevice = NO;
    }
    return self;
}

- (NSString *)nonNilMACAddress
{
    return _MACAddress ? _MACAddress : @"";
}

- (NSString *)nonNilManufacturer
{
    return _manufacturer ? _manufacturer : @"";
}

- (NSString *)nonNilModel
{
    return _model ? _model : @"";
}

- (NSString *)nonNilHostname
{
    return _hostname ? _hostname : @"";
}

@end
