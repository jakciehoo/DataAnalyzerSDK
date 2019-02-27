//
//  YRKDARemoteConfig.m
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/20.
//

#import "YRKDARemoteConfig.h"

@implementation YRKDARemoteConfig

+ (instancetype)configWithDict:(NSDictionary *)dict{
    return [[self alloc]initWithDict:dict];
}

-(instancetype)initWithDict:(NSDictionary *)dict{
    if (self = [super init]) {

    }
    return self;
}

@end
