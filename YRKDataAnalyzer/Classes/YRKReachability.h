//
//  YRKReachability.h
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/21.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>


typedef enum : NSInteger {
    YRKNotReachable = 0,
    YRKReachableViaWiFi,
    YRKReachableViaWWAN
} YRKNetworkStatus;

#pragma mark IPv6 Support
//Reachability fully support IPv6.  For full details, see ReadMe.md.

extern NSString *kYRKReachabilityChangedNotification;


NS_ASSUME_NONNULL_BEGIN

@interface YRKReachability : NSObject

/*!
 * Use to check the reachability of a given host name.
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * Use to check the reachability of a given IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;

/*!
 * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
 */
+ (instancetype)reachabilityForInternetConnection;


- (YRKNetworkStatus)currentReachabilityStatus;

@end

NS_ASSUME_NONNULL_END
