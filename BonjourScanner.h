//
//  BonjourScanner.h
//  Cammy
//
//  Created by Jimmy Lee on 8/08/2014.
//  Copyright (c) 2014 SELU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JLHTTPDevice.h"

@interface BonjourScanner : NSObject<NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, copy) void (^foundDevice)(JLHTTPDevice *device);
- (void)scan:(void (^)(BOOL finished))scanCompleteBlock;
- (void)stop;

@end
