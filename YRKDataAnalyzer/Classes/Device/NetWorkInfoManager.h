//
//  NetWorkInfoManager.h
//  ClientTest
//
//  Created by Leon on 2017/8/23.
//  Copyright © 2017年 王鹏飞. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetWorkInfoManager : NSObject


+ (instancetype)sharedManager;

/** 获取设备本机ip */
+ (NSString *)getLocalIPAddress:(BOOL)preferIPv4;
//获取设备外网IP
+ (NSString *)getWlanIPAddress;

+ (NSString *)getIpAddressWIFI;//wifi情况下的IP
+ (NSString *)getIpAddressCellular;//3g、4g的IP

@end
