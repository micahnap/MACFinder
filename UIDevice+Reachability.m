//
//  UIDevice+Reachability.m
//  Cammy
//  Copied code from Erica Sadun and other, with modifications
//  Created by Jimmy Lee on 3/12/2013.
//  Copyright (c) 2013 SELU. All rights reserved.
//

#import "UIDevice+Reachability.h"

/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 5.0 Edition
 BSD License for anything not specifically marked as developed by a third party.
 Apple's code excluded.
 Use at your own risk
 */

#import <SystemConfiguration/SystemConfiguration.h>

#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <unistd.h>
#import <dlfcn.h>


#include <sys/param.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <net/if_dl.h>

#include <netinet/in.h>

#ifdef __APPLE__
#include "TargetConditionals.h"
#endif

#if TARGET_IPHONE_SIMULATOR
#include <net/if_types.h>
#include <net/route.h>
#include <netinet/if_ether.h>
#else
#include "if_types.h"
#include "route.h"
#include "if_ether.h"
#endif


#include <arpa/inet.h>

#include <err.h>
#include <errno.h>
#include <netdb.h>

#include <paths.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CTL_NET         4
#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

#if defined(BSD) || defined(__APPLE__)
#define ROUNDUP(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))


@implementation UIDevice (Reachability)
SCNetworkConnectionFlags connectionFlags;
SCNetworkReachabilityRef reachability;

#pragma mark Class IP and Host Utilities

struct in_addr gatewayaddr;


int getdefaultgateway(in_addr_t * addr)
{
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET,
        NET_RT_FLAGS, RTF_GATEWAY};
    size_t l;
    char * buf, * p;
    struct rt_msghdr * rt;
    struct sockaddr * sa;
    struct sockaddr * sa_tab[RTAX_MAX];
    int i;
    int r = -1;
    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return -1;
    }
    if(l>0) {
        buf = malloc(l);
        if(sysctl(mib, sizeof(mib)/sizeof(int), buf, &l, 0, 0) < 0) {
            return -1;
        }
        for(p=buf; p<buf+l; p+=rt->rtm_msglen) {
            rt = (struct rt_msghdr *)p;
            sa = (struct sockaddr *)(rt + 1);
            for(i=0; i<RTAX_MAX; i++) {
                if(rt->rtm_addrs & (1 << i)) {
                    sa_tab[i] = sa;
                    sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
                } else {
                    sa_tab[i] = NULL;
                }
            }
            
            if( ((rt->rtm_addrs & (RTA_DST|RTA_GATEWAY)) == (RTA_DST|RTA_GATEWAY))
               && sa_tab[RTAX_DST]->sa_family == AF_INET
               && sa_tab[RTAX_GATEWAY]->sa_family == AF_INET) {
                
                
                if(((struct sockaddr_in *)sa_tab[RTAX_DST])->sin_addr.s_addr == 0) {
                    char ifName[128];
                    if_indextoname(rt->rtm_index,ifName);
                    
                    if(strcmp("en0",ifName)==0){
                        
                        *addr = ((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr.s_addr;
                        r = 0;
                    }
                }
            }
        }
        free(buf);
    }
    return r;
}

#endif

- (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }

        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

//-(NSString *)broadCastAddressForIP
//{
//    struct ifaddrs *temp_addr;
//    struct in_addr localAddr;
//    struct in_addr netmaskAddr;
//    
//    NSString *myIP = [self getIPAddress:true];
//    
//
//    inet_aton([localIPAddress UTF8String], &localAddr);
//    inet_aton([netmaskAddress UTF8String], &netmaskAddr);
//    
//    
//    NSString *broadCastAddress = [NSString stringWithUTF8String:inet_ntoa(localAddr)];
//    
//    
//    return broadCastAddress;
//}

-(NSString *)addressForGateway
{
    int r = getdefaultgateway(&(gatewayaddr.s_addr));
    NSString *ipString;
    
    if(r>=0)
    {
        ipString = [NSString stringWithFormat: @"%s",inet_ntoa(gatewayaddr)];
        NSLog(@"default gateway : %@", ipString ); } else { NSLog(@"getdefaultgateway() failed");
    }
    
    return ipString;
}

// This IP Utilities are mostly inspired by or derived from Apple code. Thank you Apple.

+ (NSString *) stringFromAddress: (const struct sockaddr *) address
{
    if (address && address->sa_family == AF_INET)
    {
        const struct sockaddr_in* sin = (struct sockaddr_in *) address;
        return [NSString stringWithFormat:@"%@:%d", [NSString stringWithUTF8String:inet_ntoa(sin->sin_addr)], ntohs(sin->sin_port)];
    }

    return nil;
}


+ (BOOL)addressFromString:(NSString *)IPAddress address:(struct sockaddr_in *)address
{
	if (!IPAddress || ![IPAddress length]) return NO;
	
	memset((char *) address, sizeof(struct sockaddr_in), 0);
	address->sin_family = AF_INET;
	address->sin_len = sizeof(struct sockaddr_in);
	
	int conversionResult = inet_aton([IPAddress UTF8String], &address->sin_addr);
	if (conversionResult == 0)
    {
		NSAssert1(conversionResult != 1, @"Failed to convert the IP address string into a sockaddr_in: %@", IPAddress);
		return NO;
	}
	
	return YES;
}

+ (NSString *) addressFromData:(NSData *) addressData
{
    NSString *adr = nil;
	
    if (addressData != nil)
    {
		struct sockaddr_in addrIn = *(struct sockaddr_in *)[addressData bytes];
		adr = [NSString stringWithFormat: @"%s", inet_ntoa(addrIn.sin_addr)];
    }
	
    return adr;
}

+ (NSString *) portFromData:(NSData *) addressData
{
    NSString *port = nil;
	
    if (addressData != nil)
    {
		struct sockaddr_in addrIn = *(struct sockaddr_in *)[addressData bytes];
		port = [NSString stringWithFormat: @"%hu", ntohs(addrIn.sin_port)];
    }
	
    return port;
}

+ (NSData *) dataFromAddress: (struct sockaddr_in) address
{
	return [NSData dataWithBytes:&address length:sizeof(struct sockaddr_in)];
}

- (NSString *) hostname
{
	char baseHostName[256]; // Thanks, Gunnar Larisch
	int success = gethostname(baseHostName, 255);
	if (success != 0) return nil;
	baseHostName[255] = '\0';
	
#if TARGET_IPHONE_SIMULATOR
 	return [NSString stringWithFormat:@"%s", baseHostName];
#else
	return [NSString stringWithFormat:@"%s.local", baseHostName];
#endif
}

- (NSString *) getIPAddressForHost: (NSString *) theHost
{
	struct hostent *host = gethostbyname([theHost UTF8String]);
    if (!host) {herror("resolv"); return NULL; }
	struct in_addr **list = (struct in_addr **)host->h_addr_list;
	NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
	return addressString;
}

- (NSString *) localIPAddress
{
	struct hostent *host = gethostbyname([[self hostname] UTF8String]);
    if (!host) {herror("resolv"); return nil;}
    struct in_addr **list = (struct in_addr **)host->h_addr_list;
	return [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
}

// Matt Brown's get WiFi IP addy solution
// Author gave permission to use in Cookbook under cookbook license
// http://mattbsoftware.blogspot.com/2009/04/how-to-get-ip-address-of-iphone-os-v221.html
// Updates: changed en0 to en.
// More updates: TBD
- (NSString *) localWiFiIPAddress
{
	BOOL success;
	struct ifaddrs * addrs;
	const struct ifaddrs * cursor;
	
	success = getifaddrs(&addrs) == 0;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
			{
				NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
				if ([name isEqualToString:@"en"])  // Wi-Fi adapter -- was en0
					return [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
	return nil;
}

+ (NSArray *) localWiFiIPAddresses
{
	BOOL success;
	struct ifaddrs * addrs;
	const struct ifaddrs * cursor;
	
	NSMutableArray *array = [NSMutableArray array];
	
	success = getifaddrs(&addrs) == 0;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
			{
				NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
				if ([name hasPrefix:@"en"])
					[array addObject:[NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)]];
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
	
	if (array.count) return array;
	
	return nil;
}

- (NSString *)getIPAddress
{
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}


- (NSString *) whatismyipdotcom
{
	NSError *error;
    NSURL *ipURL = [NSURL URLWithString:@"http://www.whatismyip.com/automation/n09230945.asp"];
    NSString *ip = [NSString stringWithContentsOfURL:ipURL encoding:1 error:&error];
	return ip ? ip : [error localizedDescription];
}

- (BOOL) hostAvailable: (NSString *) theHost
{
	
    NSString *addressString = [self getIPAddressForHost:theHost];
    if (!addressString)
    {
        printf("Error recovering IP address from host name\n");
        return NO;
    }
	
    struct sockaddr_in address;
    BOOL gotAddress = [UIDevice addressFromString:addressString address:&address];
	
    if (!gotAddress)
    {
		printf("Error recovering sockaddr address from %s\n", [addressString UTF8String]);
        return NO;
    }
	
	SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&address);
    SCNetworkReachabilityFlags flags;
	
	BOOL didRetrieveFlags =SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
	
    if (!didRetrieveFlags)
    {
        printf("Error. Could not recover network reachability flags\n");
        return NO;
    }
	
    BOOL isReachable = flags & kSCNetworkFlagsReachable;
    return isReachable ? YES : NO;;
}

#pragma mark Checking Connections

- (void) pingReachabilityInternal
{
	if (!reachability)
	{
		BOOL ignoresAdHocWiFi = NO;
		struct sockaddr_in ipAddress;
		bzero(&ipAddress, sizeof(ipAddress));
		ipAddress.sin_len = sizeof(ipAddress);
		ipAddress.sin_family = AF_INET;
		ipAddress.sin_addr.s_addr = htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM);
        
		/* Can also create zero addy
		 struct sockaddr_in zeroAddress;
		 bzero(&zeroAddress, sizeof(zeroAddress));
		 zeroAddress.sin_len = sizeof(zeroAddress);
		 zeroAddress.sin_family = AF_INET; */
		
		reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&ipAddress);
		CFRetain(reachability);
	}
	
	// Recover reachability flags
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(reachability, &connectionFlags);
	if (!didRetrieveFlags) printf("Error. Could not recover network reachability flags\n");
}

- (BOOL) networkAvailable
{
	[self pingReachabilityInternal];
	BOOL isReachable = ((connectionFlags & kSCNetworkFlagsReachable) != 0);
    BOOL needsConnection = ((connectionFlags & kSCNetworkFlagsConnectionRequired) != 0);
    return (isReachable && !needsConnection) ? YES : NO;
}

- (BOOL) activeWWAN
{
	if (![self networkAvailable]) return NO;
	return ((connectionFlags & kSCNetworkReachabilityFlagsIsWWAN) != 0);
}

- (BOOL) activeWLAN
{
	return ([[UIDevice currentDevice] localWiFiIPAddress] != nil);
}


#pragma mark WiFi Check and Alert
- (void) privateShowAlert: (id) formatstring,...
{
	va_list arglist;
	if (!formatstring) return;
	va_start(arglist, formatstring);
	id outstring = [[NSString alloc] initWithFormat:formatstring arguments:arglist];
	va_end(arglist);
	
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:outstring message:nil delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil];
	[av show];
}

- (BOOL) performWiFiCheck
{
	if (![self networkAvailable] || ![self activeWLAN])
	{
		[self performSelector:@selector(privateShowAlert:) withObject:@"This application requires WiFi. Please enable WiFi in Settings and run this application again." afterDelay:0.5f];
		return NO;
	}
	return YES;
}

#pragma mark Forcing WWAN connection. Courtesy of Apple. Thank you Apple.
//MyStreamInfoPtr	myInfoPtr;
//static void myClientCallback(void *refCon)
//{
//	int  *val = (int*)refCon;
//	printf("myClientCallback entered - value from refCon is %d\n", *val);
//}
//
//- (BOOL) forceWWAN
//{
//	int value = 0;
//	myInfoPtr = (MyStreamInfoPtr) StartWWAN(myClientCallback, &value);
//	DLog(@"%@", myInfoPtr ? @"Started WWAN" : @"Failed to start WWAN");
//	return (!(myInfoPtr == NULL));
//}
//
//- (void) shutdownWWAN
//{
//	if (myInfoPtr) StopWWAN((MyInfoRef) myInfoPtr);
//}

#pragma mark Monitoring reachability
static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void* info)
{
    @autoreleasepool {
        id watcher = (__bridge id) info;
        SEL reachabilityChangedSelector = NSSelectorFromString(@"reachabilityChanged");
        if ([watcher respondsToSelector:reachabilityChangedSelector]) {
            
// Supress warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [watcher performSelector:reachabilityChangedSelector];
#pragma clang diagnostic pop
        }
    }
}

- (BOOL) scheduleReachabilityWatcher: (id) watcher
{
    SEL reachabilityChangedSelector = NSSelectorFromString(@"reachabilityChanged");
	if (![watcher respondsToSelector:reachabilityChangedSelector])
	{
		NSLog(@"Watcher must implement reachabilityChanged callback. Cannot continue.");
		return NO;
	}
	
	[self pingReachabilityInternal];
    
	SCNetworkReachabilityContext context = {0, (__bridge void *)watcher, NULL, NULL, NULL};
	if(SCNetworkReachabilitySetCallback(reachability, ReachabilityCallback, &context))
	{
		if(!SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopCommonModes))
		{
			NSLog(@"Error: Could not schedule reachability");
			SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
			return NO;
		}
	}
	else
	{
		NSLog(@"Error: Could not set reachability callback");
		return NO;
	}
	
	return YES;
}

- (void) unscheduleReachabilityWatcher
{
	SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
	if (SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopCommonModes)) {
		NSLog(@"Unscheduled reachability");
    }
	else {
		NSLog(@"Error: Could not unschedule reachability");
	}
	CFRelease(reachability);
	reachability = nil;
}

static int nflag;

+ (NSDictionary *)ipDetails:(char *)ip
{
    int found_entry;
    
    NSString *hostString = nil;
    NSString *mAddr = nil;
    u_long addr = inet_addr(ip);
    int mib[6];
    size_t needed;
    char *host, *lim, *buf, *next;
    struct rt_msghdr *rtm;
    struct sockaddr_inarp *sin;
    struct sockaddr_dl *sdl;
    extern int h_errno;
    struct hostent *hp;
    
    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_INET;
    mib[4] = NET_RT_FLAGS;
    mib[5] = RTF_LLINFO;
    if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
        err(1, "route-sysctl-estimate");
    if ((buf = malloc(needed)) == NULL)
        err(1, "malloc");
    if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
        err(1, "actual retrieval of routing table");
    
    
    lim = buf + needed;
    for (next = buf; next < lim; next += rtm->rtm_msglen) {
        rtm = (struct rt_msghdr *)next;
        sin = (struct sockaddr_inarp *)(rtm + 1);
        sdl = (struct sockaddr_dl *)(sin + 1);
        if (addr) {
            if (addr != sin->sin_addr.s_addr)
                continue;
            found_entry = 1;
        }
        if (nflag == 0)
            hp = gethostbyaddr((caddr_t)&(sin->sin_addr),
                               sizeof sin->sin_addr, AF_INET);
        else
            hp = 0;
        if (hp)
            host = hp->h_name;
        else {
            host = "?";
            if (h_errno == TRY_AGAIN)
                nflag = 1;
        }
        
        hostString = [NSString stringWithCString:host encoding:NSUTF8StringEncoding];
        NSLog(@"Host: %@", hostString);
        
        if (sdl->sdl_alen) {
            
            u_char *cp = (u_char *)LLADDR(sdl);
            
            //mAddr = [NSString stringWithFormat:@"%x:%x:%x:%x:%x:%x", cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]];
            mAddr = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X", cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]];
            
            //  ether_print((u_char *)LLADDR(sdl));
        }
        else
            mAddr = nil;
    }
    
    
    if (found_entry == 0) {
        free(buf);
        return nil;
    } else {
        free(buf);
        
        return @{ @"mac" : mAddr ? mAddr : @"",
                  @"hostname" : hostString ? hostString : @"" };
    }
}

+ (NSString *)ip2mac:(char *)ip
{
    if (!ip) {
        return nil;
    }
    
    int found_entry;
    
    NSString *mAddr = nil;
    u_long addr = inet_addr(ip);
    int mib[6];
    size_t needed;
    char *host, *lim, *buf, *next;
    struct rt_msghdr *rtm;
    struct sockaddr_inarp *sin;
    struct sockaddr_dl *sdl;
    extern int h_errno;
    struct hostent *hp;
    
    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_INET;
    mib[4] = NET_RT_FLAGS;
    mib[5] = RTF_LLINFO;
    if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
        err(1, "route-sysctl-estimate");
    if ((buf = malloc(needed)) == NULL)
        err(1, "malloc");
    if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
        err(1, "actual retrieval of routing table");
    
    
    lim = buf + needed;
    for (next = buf; next < lim; next += rtm->rtm_msglen) {
        rtm = (struct rt_msghdr *)next;
        sin = (struct sockaddr_inarp *)(rtm + 1);
        sdl = (struct sockaddr_dl *)(sin + 1);
        if (addr) {
            if (addr != sin->sin_addr.s_addr)
                continue;
            found_entry = 1;
        }
        if (nflag == 0)
            hp = gethostbyaddr((caddr_t)&(sin->sin_addr),
                               sizeof sin->sin_addr, AF_INET);
        else
            hp = 0;
        if (hp)
            host = hp->h_name;
        else {
            host = "?";
            if (h_errno == TRY_AGAIN)
                nflag = 1;
        }
        
        if (sdl->sdl_alen) {
            
            u_char *cp = (u_char *)LLADDR(sdl);
            
            //mAddr = [NSString stringWithFormat:@"%x:%x:%x:%x:%x:%x", cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]];
            mAddr = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X", cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]];
            
            //  ether_print((u_char *)LLADDR(sdl));
        }
        else
            mAddr = nil;
    }
    
    
    if (found_entry == 0) {
        free(buf);
        return nil;
    } else {
        free(buf);
        return mAddr;
    }
}

+ (NSString *)mac2ip:(NSString *)mac
{
    int mib[6];
    size_t needed;
    char *lim, *buf, *next;
    struct rt_msghdr *rtm;
    struct sockaddr_inarp *sin;
    struct sockaddr_dl *sdl;
    extern int h_errno;
    
    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_INET;
    mib[4] = NET_RT_FLAGS;
    mib[5] = RTF_LLINFO;
    if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
        err(1, "route-sysctl-estimate");
    if ((buf = malloc(needed)) == NULL)
        err(1, "malloc");
    if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
        err(1, "actual retrieval of routing table");
    
    
    lim = buf + needed;
    for (next = buf; next < lim; next += rtm->rtm_msglen) {
        rtm = (struct rt_msghdr *)next;
        sin = (struct sockaddr_inarp *)(rtm + 1);
        sdl = (struct sockaddr_dl *)(sin + 1);
        
        u_char *cp = (u_char *)LLADDR(sdl);
        NSString *currentMAC = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X", cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]];
        //DLog(@"MAC: %@", mac);
        
        if ([currentMAC isEqualToString:mac]) {
            //if (addr != sin->sin_addr.s_addr)
            //    continue;
            NSString *ipAddress = [NSString stringWithUTF8String:inet_ntoa(sin->sin_addr)];
            
            if ([ipAddress rangeOfString:@"169."].location != 0) {
                //DLog(@"FOUND: %@", ipAddress);
                free(buf);
                return ipAddress;
            }
        }
    }
    free(buf);
    return nil;
}

- (NSString *)getBroadCastAddress
{
    NSString * broadcastAddr= @"Error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    
    if (success == 0)
    {
        temp_addr = interfaces;
        
        while(temp_addr != NULL)
        {
            // check if interface is en0 which is the wifi connection on the iPhone
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    broadcastAddr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_dstaddr)->sin_addr)];
                    
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return broadcastAddr;
}

@end